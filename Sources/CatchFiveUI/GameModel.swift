import CatchFive
import Combine
import Foundation

/// Solo is one human at seat 0 against three computers; pass and play is four humans sharing one phone.
public enum PlayMode: String, Codable, Sendable {
    case solo, passAndPlay

    /// The New match question's explanation of the two choices.
    public static let choiceMessage = "Solo: you and three computer players. Pass and play: four players share this phone, passing it for each turn."
}

@MainActor
public final class GameModel: ObservableObject {
    @Published public private(set) var match: Match
    /// Saved beside the game, so a pass-and-play match resumes as one.
    @Published public private(set) var mode: PlayMode
    /// In pass and play, the seat that pressed Ready and now holds the phone; nil while the curtain is up.
    @Published public private(set) var revealedSeat: Int?
    @Published public private(set) var revision = 0
    @Published public var errorMessage: String?
    /// A failed write of the game, settings or history. The move it followed was accepted and stands;
    /// `retrySave()` writes the same state again and never replays anything.
    @Published public var saveError: String?
    /// Hand-history failures never make an accepted move fail or replace the real game's save.
    @Published public private(set) var archiveError: String?
    /// The computer strategy's advice for the human seat, shown on request and cleared by the next action.
    @Published public private(set) var hint: Advice?
    /// Why a card on the table or in the last trick was played; toggled by tapping it.
    @Published public private(set) var explanation: String?
    /// A one-line note about something that happened without a tap, such as the discard after trump.
    @Published public private(set) var notice: String?
    /// The table's note that a computer team down 10 or more is bidding one step bolder (D71); shown once
    /// per hand when one of its seats calls, and faded by the table after a few seconds.
    @Published public private(set) var boldNote: String?
    /// The hand the bold note was last shown in, so it is said once per hand.
    private var boldNoteHand: Int?
    /// How the first dealer of this match was chosen; shown until the first action, or dismissed.
    @Published private(set) var dealerDraw: DealerDraw?
    /// Why the human's last refused tap was refused, in the player's words; cleared by the next accepted action.
    @Published public private(set) var refusal: String?
    /// The human's most recent accepted action, for the undo toast and haptics; nil after undo or a new hand.
    @Published public private(set) var lastHumanAction: PlayerAction?
    @Published public var settings: Settings { didSet { persistSettings() } }
    /// Every finished match, oldest first.
    @Published public private(set) var records: [MatchRecord]
    /// The human's record for a finished solo match, computed once when it is recorded or restored.
    @Published public private(set) var finalPerformance: SeatPerformance?
    /// The player's own count of trumps played this hand, kept by tapping the trump tile (D65). View state
    /// only: the engine, the computers and the save never see it, and it clears when the next hand starts.
    @Published public private(set) var trumpTally = 0
    /// Seats the player has marked as out of trump this hand, by tapping their portrait (D65); view state only.
    @Published public private(set) var outOfTrump: Set<Int> = []
    private let saveURL: URL?
    private let settingsURL: URL?
    private let historyURL: URL?
    private let practice: PracticeConfiguration?
    private let archiveDirectory: URL?
    private var archiveStore: HandArchiveStore?
    private var archiveReadGeneration = 0
    private var archivedIDs: Set<String> = []
    private struct PendingArchive {
        let match: Match
        let date: Date
        let names: [String]
        let opponents: Settings.Opponents
        let mode: PlayMode
        let difficulty: Difficulty
        let recovered: Bool
    }
    private var pendingArchives: [String: PendingArchive] = [:]
    /// Set once the current match has been recorded, and when a match is restored already finished.
    private var recordedCurrentMatch: Bool
    /// Supplies the date of a record; injectable for tests.
    public var now: () -> Date = Date.init

    public init(match: Match, mode: PlayMode = .solo, saveURL: URL? = nil, settings: Settings = Settings(), settingsURL: URL? = nil,
                records: [MatchRecord] = [], historyURL: URL? = nil,
                practice: PracticeConfiguration? = nil, archiveDirectory: URL? = nil) {
        self.match = match
        self.mode = practice == nil ? mode : .solo
        self.saveURL = practice == nil ? saveURL : nil
        self.settings = settings
        self.settingsURL = practice == nil ? settingsURL : nil
        self.records = practice == nil ? records : []
        self.historyURL = practice == nil ? historyURL : nil
        self.practice = practice
        self.archiveDirectory = practice == nil ? archiveDirectory : nil
        recordedCurrentMatch = match.winner != nil
        if practice == nil, match.winner != nil, mode == .solo { finalPerformance = try? match.performance(forSeat: 0) }
        if self.archiveDirectory != nil { retryArchive() }
    }

    public var statistics: Statistics { Statistics(records) }
    public var isPractice: Bool { practice != nil }

    /// One source for a seat's moves and the words describing its strategy.
    public func effectiveDifficulty(forSeat seat: Int) -> Difficulty {
        practice?.difficulty(forSeat: seat) ?? settings.difficulty
    }

    public func makePractice(configuration: PracticeConfiguration, replay: HandReplay? = nil) throws -> GameModel {
        let deal = try replay?.practiceMatch() ?? Match(deck: configuration.deal.deck(), dealer: 3)
        return GameModel(match: deal, settings: settings, practice: configuration)
    }

    public func handReplay(number: Int? = nil) -> HandReplay? {
        try? HandReplay(match: match, handNumber: number)
    }

    public func savedHands(limit: Int = 50) -> HandArchiveListing {
        guard let archiveStore else { return HandArchiveListing() }
        do {
            let listing = try archiveStore.entries(limit: limit, excludingDealID: activeArchiveDealID())
            if !listing.unreadableFiles.isEmpty {
                archiveError = "Some saved hands could not be read. Other hands are still available."
            }
            return listing
        } catch {
            archiveError = "Saved hands could not be opened. Your current game is still safe."
            return HandArchiveListing()
        }
    }

    struct ArchiveReadContext: Hashable, Sendable {
        let store: ObjectIdentifier?
        let scope: UUID?
        let activeDeal: String?
        let playerName: String?
    }

    var archiveReadContext: ArchiveReadContext {
        ArchiveReadContext(store: archiveStore.map(ObjectIdentifier.init), scope: archiveStore?.scopeID,
                           activeDeal: try? activeArchiveDealID(), playerName: settings.playerName)
    }

    public func savedHandsAsync(limit: Int = 50) async -> HandArchiveListing? {
        await savedHandsAsync(limit: limit, reader: { try $0.read() })
    }

    /// The detached worker owns only an immutable request; all state/error publication stays on this actor.
    func savedHandsAsync(limit: Int = 50,
                         reader: @escaping @Sendable (HandArchiveReadRequest) throws -> HandArchiveListing) async -> HandArchiveListing? {
        guard !Task.isCancelled else { return nil }
        archiveReadGeneration += 1
        let generation = archiveReadGeneration
        let context = archiveReadContext
        guard let archiveStore else { return HandArchiveListing() }
        let request = archiveStore.readRequest(limit: limit, excludingDealID: context.activeDeal)
        let worker = Task.detached(priority: .userInitiated) { try reader(request) }
        let result = await withTaskCancellationHandler {
            await worker.result
        } onCancel: { worker.cancel() }
        guard !Task.isCancelled, generation == archiveReadGeneration, context == archiveReadContext else { return nil }
        switch result {
        case let .success(listing):
            if !listing.unreadableFiles.isEmpty {
                archiveError = "Some saved hands could not be read. Other hands are still available."
            }
            return listing
        case .failure(is CancellationError): return nil
        case .failure:
            archiveError = "Saved hands could not be opened. Your current game is still safe."
            return HandArchiveListing()
        }
    }

    public var archiveStatistics: HandArchiveStatistics {
        guard let archiveStore, let listing = try? archiveStore.entries(limit: .max, excludingDealID: activeArchiveDealID()) else {
            return HandArchiveStatistics()
        }
        return HandArchiveStatistics(listing.entries)
    }

    private func activeArchiveDealID() throws -> String? {
        match.hand.phase == .finished ? nil : try HandArchiveStore.dealIdentity(for: match)
    }

    public func retryArchive() {
        guard let archiveDirectory, !isPractice else { return }
        archiveError = nil
        do {
            // Keep recoverable snapshots even when opening the store fails. A later new game must not
            // discard the only in-memory copy or replace its recovery date and names on the next retry.
            for summary in match.history {
                let replay = try HandReplay(match: match, handNumber: summary.number)
                captureArchive(replay.finishedMatch, recovered: true)
            }
            if archiveStore == nil { archiveStore = try HandArchiveStore(directory: archiveDirectory) }
            flushArchive()
        } catch {
            archiveError = "Saved hands could not be opened. Your current game is still safe."
        }
    }

    private func captureArchive(_ completed: Match, recovered: Bool) {
        guard archiveDirectory != nil, !isPractice else { return }
        do {
            let id = try HandArchiveStore.identity(for: completed)
            guard !archivedIDs.contains(id) else { return }
            if pendingArchives[id] == nil {
                pendingArchives[id] = PendingArchive(match: completed, date: now(), names: seatNames,
                                                     opponents: settings.opponents, mode: mode,
                                                     difficulty: settings.difficulty, recovered: recovered)
            }
            flushArchive()
        } catch { archiveError = "This hand could not be saved yet. Your current game is still safe; try again." }
    }

    private func flushArchive() {
        guard let archiveStore else { return }
        for (id, pending) in pendingArchives {
            do {
                try archiveStore.save(pending.match, date: pending.date, names: pending.names,
                                      opponents: pending.opponents, mode: pending.mode,
                                      difficulty: pending.difficulty, recovered: pending.recovered)
                archivedIDs.insert(id)
                pendingArchives.removeValue(forKey: id)
            } catch { archiveError = "This hand could not be saved yet. Your current game is still safe; try again." }
        }
    }

    public func dismissDealerDraw() { dealerDraw = nil }

    /// A fresh match with the dealer decided by a draw, shown on the table until the first action.
    static func freshMatch() -> (match: Match, draw: DealerDraw) {
        let draw = DealerDraw.draw(from: deck())
        // The generated deck is always a valid, unique 52-card deck.
        return (try! Match(deck: deck(), dealer: draw.dealer), draw)
    }

    /// The finished hand's outcome in the player's order: contract, arithmetic, defenders, deciding rules.
    var lastHandOutcome: HandOutcome? {
        let history = match.history
        guard let last = history.last else { return nil }
        let before = history.count > 1 ? history[history.count - 2].scores : [0, 0]
        return HandOutcome(summary: last, before: before, names: seatNames)
    }

    /// One seat's line on the hand-end card (N36): only once the hand is over, and only in solo, where
    /// "you" and "your partner" are clear; pass and play shows none.
    var handEndLine: HandEndLine? {
        guard mode == .solo, match.hand.phase == .finished, let last = match.history.last else { return nil }
        return HandEndLine(summary: last)
    }

    /// The last hand read as a 9 and out, when it was one: who bid it and which points were missed (D69).
    var lastNineAndOut: NineAndOutResult? { match.history.last.flatMap(NineAndOutResult.init(summary:)) }

    /// What plays before the match-over card once the match is won: the 9-and-out screen, the cascade, both or neither (D69).
    var celebrations: [Celebration] { Celebration.steps(winner: match.winner, mode: mode, nineAndOut: lastNineAndOut) }

    /// Every play of the finished hand alongside the standard strategy's choice; nil before the hand is scored.
    public func handReview() -> HandReview? {
        guard match.hand.phase == .finished else { return nil }
        return try? HandReview(match: match)
    }

    /// Statistics are the phone owner's solo record, so a pass-and-play match is never recorded.
    private func recordMatchIfFinished() {
        guard match.winner != nil, !recordedCurrentMatch else { return }
        recordedCurrentMatch = true
        guard mode == .solo, !isPractice else { return }
        let performance = (try? match.performance(forSeat: 0)) ?? SeatPerformance(plays: 0, playsAgreed: 0, bids: 0, bidsMade: 0)
        finalPerformance = performance
        records.append(MatchRecord(date: now(), scores: match.scores, winner: match.winner ?? 0, hands: match.history.count,
                                   difficulty: settings.difficulty, humanBids: performance.bids, humanBidsMade: performance.bidsMade,
                                   humanPlays: performance.plays, humanPlaysAgreed: performance.playsAgreed))
        persistHistory()
    }

    /// Whether a person, not the computer, plays `seat`: every seat in pass and play, seat 0 in solo.
    public func isHuman(_ seat: Int) -> Bool { mode == .passAndPlay || seat == 0 }

    /// The seat whose hand the phone shows: seat 0 in solo; in pass and play only the seat that pressed Ready.
    public var viewerSeat: Int? { mode == .solo ? 0 : revealedSeat }

    /// In pass and play, the seat the phone must be passed to before anything of theirs is shown.
    public var curtainSeat: Int? {
        guard mode == .passAndPlay, match.winner == nil, let next = match.hand.nextSeat, next != revealedSeat else { return nil }
        return next
    }

    /// The player the phone was passed to says so; their hand appears.
    public func ready() {
        revealedSeat = curtainSeat ?? revealedSeat
        if let revealedSeat { lastRevealedSeat = revealedSeat }
    }

    /// The seat drawn at the bottom of the table: the phone holder's. In pass and play the table turns to the
    /// next holder while their curtain is up, and stays with the last one between hands.
    public var bottomSeat: Int { viewerSeat ?? curtainSeat ?? lastRevealedSeat }
    private var lastRevealedSeat = 0

    /// The seat at a place round the table, counted from the bottom: 1 on the left, 2 across, 3 on the right.
    /// Play passes to the left, so the seat after the phone holder sits on their left.
    public func seat(at place: Int) -> Int { (bottomSeat + place) % 4 }

    /// Where `seat` sits round the table as the phone holder sees it: 0 at the bottom, 1 left, 2 across, 3 right.
    public func place(of seat: Int) -> Int { (seat - bottomSeat + 4) % 4 }

    public var isHumanTurn: Bool { match.winner == nil && match.hand.nextSeat != nil && match.hand.nextSeat == viewerSeat }
    /// In pass and play every seat is a family member, so seat 0 drops the phone holder's own name.
    public var seatNames: [String] { settings.names(passAndPlay: mode == .passAndPlay) }

    /// True once something has happened this match and nobody has won yet; drives the menu's Continue button.
    public var matchInProgress: Bool { match.actionCount > 0 && match.winner == nil }

    /// One line for the welcome card: where the saved match stands, or nil when there is nothing to resume.
    public var resumeContext: String? {
        guard matchInProgress else { return nil }
        let phase: String = switch match.hand.phase {
        case .bidding: "bidding"
        case .choosingTrump: "choosing trump"
        case .playing: "playing"
        case .finished: "hand scored"
        }
        let scores = mode == .solo ? "Your team \(match.scores[0]), their team \(match.scores[1])"
            : "\(teamNames(0)) \(match.scores[0]), \(teamNames(1)) \(match.scores[1])"
        return "Hand \(match.handNumber) · \(scores) · \(phase)"
    }

    /// The pair sitting as `team`: "Cheryl + Connor".
    public func teamNames(_ team: Int) -> String { "\(seatNames[team]) + \(seatNames[team + 2])" }

    /// The phone holder's partner, across the table: the seat that asks before a 9-and-out bid (D70).
    public var partnerSeat: Int { (bottomSeat + 2) % 4 }

    /// The team the score bar leads with as "Us": the phone holder's.
    public var ourTeam: Int { bottomSeat % 2 }

    /// The status line once `team` has won: yours in solo, and by name otherwise.
    public func winnerHeadline(_ team: Int) -> String {
        mode == .solo && team == 0 ? "Your team wins the match" : "\(teamNames(team)) win the match"
    }

    /// The login screen's one write: the trimmed name becomes seat 0's name unless another seat has it.
    public func signIn(name: String, portrait: Portrait, difficulty: Difficulty) {
        var updated = settings
        updated.setPlayerName(name)
        guard updated.hasSignedIn else { return }
        updated.playerPortrait = portrait
        updated.difficulty = difficulty
        settings = updated   // one write, one save
    }

    /// Starts over as a new player (D108): the name and face go back to unset, so the set-up screen shows again, the
    /// saved match gives way to a fresh solo deal, and the match records behind Statistics are emptied.
    @discardableResult public func resetPlayer() -> Bool {
        if archiveDirectory != nil {
            retryArchive()
            guard pendingArchives.isEmpty else {
                archiveError = "Some hands could not be saved. Try saving them again before starting a new player."
                return false
            }
            do {
                guard let archiveStore else { throw HandArchiveError.invalidScope }
                try archiveStore.beginNewPlayer()
            } catch {
                archiveError = "Could not start a new player. Your current player and game have been kept."
                return false
            }
        }
        archivedIDs = []
        pendingArchives = [:]
        archiveError = nil
        var updated = settings
        if updated.seatNames[0] == updated.playerName { updated.seatNames[0] = Settings.defaultSeatNames[0] }
        updated.playerName = nil
        updated.playerPortrait = Cast.defaultPlayerPortrait
        settings = updated   // one write, one save
        records = []
        persistHistory()
        newGame(mode: .solo)
        return true
    }

    /// One VoiceOver sentence for a seat tile: name, direction, call or card count, dealer, to act.
    public func seatSummary(for seat: Int) -> String {
        let hand = match.hand
        var parts = [seatNames[seat]]
        if place(of: seat) != 0 { parts.append(Cast.seatWords[place(of: seat)]) }
        if hand.phase == .bidding { parts.append(latestCall(for: seat) ?? "waiting") }
        else if hand.auction.winner == seat { parts.append("bidder") }
        if hand.auction.dealer == seat { parts.append("dealer") }
        if hand.nextSeat == seat, match.winner == nil { parts.append("to act") }
        return parts.joined(separator: ", ")
    }

    /// The hand as shown: trumps first, highest to lowest, then the other suits in a fixed order.
    public var humanCards: [Card] {
        let trump = match.hand.trump
        guard let seat = viewerSeat else { return [] }
        return match.hand.hands[seat].sorted { a, b in
            if (a.suit == trump) != (b.suit == trump) { return a.suit == trump }
            if a.suit != b.suit { return Suit.allCases.firstIndex(of: a.suit)! < Suit.allCases.firstIndex(of: b.suit)! }
            return a.rank.rawValue > b.rank.rawValue
        }
    }

    public func send(_ action: PlayerAction) {
        guard isHumanTurn, let seat = viewerSeat else { TableTrace.log("send dropped, not your turn: \(action)"); return }
        TableTrace.log("send \(action) seat \(seat)")
        notice = nil
        let announces = namesTrump(action)
        if perform({ try match.apply(action, seat: seat) }) {
            if announces { notice = discardAnnouncement() }
            lastHumanAction = action
            // The phone passes on: the curtain comes down before the next seat sees anything.
            if mode == .passAndPlay, match.hand.nextSeat != seat { revealedSeat = nil }
        }
    }
    public func stepComputer() {
        guard match.winner == nil, let seat = match.hand.nextSeat, !isHuman(seat) else { TableTrace.log("computer step skipped"); return }
        var announces = false
        // Read before the call: the auction may close on it, and the note belongs to the hand it was made in.
        let hand = match.handNumber
        let bold = boldNoteHand == hand ? nil : boldNote(for: seat)
        let acted = perform {
            let view = try PlayerView(match: match, seat: seat)
            guard let action = ComputerPlayer.decide(view, difficulty: effectiveDifficulty(forSeat: seat)) else { TableTrace.log("computer \(seat) has no move"); return }
            TableTrace.log("computer \(seat) \(action)")
            announces = namesTrump(action)
            try match.apply(action, seat: seat)
        }
        if announces { notice = discardAnnouncement() }
        if acted, let bold {
            boldNote = bold
            boldNoteHand = hand
        }
    }

    /// What the table says when computer `seat` calls in the auction while its team is down 10 or more (D71):
    /// "JC and Diane are down 12, bidding bolder." Nil for a person, an Easy computer, or a team not that far
    /// behind; the same `ComputerPlayer.isTrailingBadly` that raises the bid decides it.
    public func boldNote(for seat: Int) -> String? {
        guard !isHuman(seat), effectiveDifficulty(forSeat: seat) == .standard, match.hand.phase == .bidding,
              let view = try? PlayerView(match: match, seat: seat), ComputerPlayer.isTrailingBadly(view) else { return nil }
        return Self.boldNoteText(team: [seat % 2, seat % 2 + 2], deficit: ComputerPlayer.deficit(view),
                                 names: seatNames, solo: mode == .solo)
    }

    public func clearBoldNote() { boldNote = nil }

    /// The note's wording; in solo your own seat reads "You", and only your partner is the one bidding bolder.
    static func boldNoteText(team: [Int], deficit: Int, names: [String], solo: Bool) -> String {
        if solo, team.contains(0) {
            return "You and \(names[2]) are down \(deficit); \(names[2]) is bidding bolder."
        }
        return "\(names[team[0]]) and \(names[team[1]]) are down \(deficit), bidding bolder."
    }

    /// True when `action` is the one that names trump, after which every seat discards and refills.
    private func namesTrump(_ action: PlayerAction) -> Bool {
        if case .chooseTrump = action { return match.hand.phase == .choosingTrump }
        return false
    }

    /// What the table says once trump is named. At a real table every player announces how many cards
    /// they are throwing, and everyone counts from it: six each afterwards, so a seat that threw n kept
    /// 6 − n trumps. Said once, like the table says it — the app never keeps the tally (spec R4, R20).
    public func discardAnnouncement() -> String {
        let counts = match.hand.discardCounts
        let spoken = (0..<4).map { seat in
            let who = seat == 0 && mode == .solo ? "You" : seatNames[seat]
            return counts[seat] == 0 ? "\(who) none" : "\(who) \(counts[seat])"
        }
        return "Discarded: " + spoken.joined(separator: " · ")
    }

    /// Wording for a seat's most recent auction call, or nil if that seat has not called yet.
    public func latestCall(for seat: Int) -> String? {
        match.hand.auction.calls.last { $0.seat == seat }.map { call in
            switch call.bid {
            case nil: "Pass"
            case .nineAndOut: "9 and out"
            case let .points(amount): "Bid \(amount)"
            }
        }
    }

    /// Who won the auction and for how much, once bidding has ended.
    public var contract: String? {
        let auction = match.hand.auction
        guard auction.nextSeat == nil, let bidder = auction.winner, let bid = auction.highestBid else { return nil }
        return "\(seatNames[bidder]) bid \(auction.isNineAndOut ? "9 and out" : String(bid))"
    }

    /// VoiceOver wording for a played card: "West played the ten of hearts".
    public func spokenDescription(of play: Play, winner: Int? = nil) -> String {
        let base = "\(seatNames[play.seat]) played the \(play.card.name)"
        return winner == play.seat ? base + " and took the hand" : base
    }

    /// VoiceOver value for a card in the human's hand.
    public func accessibilityValue(for card: Card) -> String {
        switch match.hand.phase {
        case .bidding, .choosingTrump: return "waiting for the auction to finish"
        case .finished: return "hand complete"
        case .playing:
            guard isHumanTurn else { return "waiting for your turn" }
            return allows(.play(card)) ? "playable" : "not legal now"
        }
    }

    /// Whether the human's latest action in this hand can be taken back.
    /// Solo only: in pass and play an undo would reach back across another player's turn.
    public var canUndo: Bool { mode == .solo && match.undoPoint(forSeat: 0) != nil }

    /// Take back the human's latest action in this hand and every computer reply after it.
    public func undo() {
        guard canUndo, let point = match.undoPoint(forSeat: 0) else { return }
        perform { match = try match.rewound(toActionCount: point) }
        lastHumanAction = nil
        notice = nil
        // Taking back the trump call takes the tally with it; there is no trump left to count.
        if match.hand.trump == nil { clearTrumpTally() }
    }

    /// Short wording for the undo toast: "9♣ played", "Bid 3", "Passed".
    public func describe(_ action: PlayerAction) -> String {
        switch action {
        case let .play(card): "\(card.label)\(card.suit.glyph) played"
        case .bid(nil): "Passed"
        case let .bid(amount?): "Bid \(amount)"
        case .nineAndOut: "Bid 9 and out"
        case let .chooseTrump(suit): "\(suit.glyph) named trump"
        }
    }

    /// The tutorial's state, sharing completion with `Settings` so it persists with the other preferences.
    public func makeTutorial() -> TutorialModel {
        TutorialModel(completed: settings.completedLessons) { [weak self] completed in self?.settings.completedLessons = completed }
    }

    /// The tip the card shows next, and the index moved on and saved, so the next visit carries on from here (D67).
    func takeNextTip() -> TipDeck.Face {
        let face = TipDeck.face(settings.nextTip)
        settings.nextTip = (settings.nextTip % TipDeck.cycle + TipDeck.cycle + 1) % TipDeck.cycle
        return face
    }

    /// True until the player has dismissed the tutorial once.
    public var needsRulesIntroduction: Bool { !settings.hasSeenRules }
    public func markRulesSeen() { settings.hasSeenRules = true }

    /// Ask the computer strategy what it would do from seat 0 and why.
    public func showHint() {
        guard isHumanTurn, let seat = viewerSeat, let view = try? PlayerView(match: match, seat: seat) else { return }
        refusal = nil   // the player asked for something newer than the last refusal
        hint = ComputerPlayer.advise(view)
    }

    /// Plain words for why `play` happened, from the strategy's point of view at that moment.
    /// `trickIndex` names a completed trick; nil means the card is still on the table.
    public func explanation(for play: Play, inLastTrick: Bool, trickIndex: Int? = nil) -> String? {
        // The reason for another seat's card is drawn from that seat's hand; the next player must not read it.
        guard match.hand.phase == .finished || (curtainSeat == nil && viewerSeat == play.seat) else { return nil }
        let index = trickIndex ?? (inLastTrick ? match.hand.completedTricks.count - 1 : nil)
        guard let view = try? PlayerView(match: match, replaying: play, inCompletedTrick: index),
              let advice = ComputerPlayer.advise(view) else { return nil }
        return describe(PlayReview(play: play, advice: advice))
    }

    /// One sentence for a reviewed play; the same wording serves tap-to-explain and the hand review.
    public func describe(_ review: PlayReview) -> String {
        let play = review.play, advice = review.advice
        // Advice reads "Play the X: reason"; keep only the reason after the colon.
        let reason = advice.reason.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? advice.reason
        let name = seatNames[play.seat]
        if play.seat != 0, effectiveDifficulty(forSeat: play.seat) == .easy {
            // Easy seats follow the old fixed rules, so show what the standard strategy would have done.
            if case let .play(preferred) = advice.action, preferred != play.card {
                return "\(name) (easy) played the \(play.card.name). Standard would have played the \(preferred.name): \(reason)"
            }
            return "\(name) (easy) played the \(play.card.name), as Standard would: \(reason)"
        }
        if play.seat == 0, !review.agreed, case let .play(preferred) = advice.action {
            return "You played the \(play.card.name). The strategy would have played the \(preferred.name): \(reason)"
        }
        return "\(name) played the \(play.card.name): \(reason)"
    }

    /// Show the explanation for a played card, or hide it if it is already showing.
    public func explain(_ play: Play, inLastTrick: Bool) {
        let text = explanation(for: play, inLastTrick: inLastTrick)
        refusal = nil
        explanation = explanation == text ? nil : text
    }

    public func allows(_ action: PlayerAction) -> Bool {
        guard isHumanTurn, let seat = viewerSeat else { return false }
        var copy = match
        return (try? copy.apply(action, seat: seat)) != nil
    }

    /// Nil when the engine would accept `action` from the human right now; otherwise the reason it would
    /// not, in the player's words. Validates on a copy, so the match and its action count never change.
    public func validationMessage(for action: PlayerAction) -> String? {
        guard match.winner == nil else { return Self.message(for: MatchError.matchFinished) }
        guard isHumanTurn, let seat = viewerSeat else {
            return match.hand.nextSeat.map { "Wait for \(seatNames[$0])." } ?? "This hand is over."
        }
        var copy = match
        do {
            try copy.apply(action, seat: seat)
            return nil
        } catch HandError.mustFollowSuit {
            guard let led = match.hand.currentTrick.first?.card.suit else { return Self.message(for: HandError.mustFollowSuit) }
            return "Follow \(led.rawValue); you still have \(led.rawValue)."
        } catch {
            return Self.message(for: error)
        }
    }

    /// Records why a tap was refused so the table can say so inline. Nothing about the match changes.
    public func refuse(_ action: PlayerAction) {
        refusal = validationMessage(for: action)
    }

    /// The player picked a card after a refusal (D97): the refusal is no longer the newest thing on the table.
    public func clearRefusal() { refusal = nil }

    /// The suit you are obliged to follow right now: the suit led, while it is your turn to play and you
    /// still hold it. Nil when you lead, when you cannot follow, or when it is not your turn.
    public var suitToFollow: Suit? {
        guard isHumanTurn, match.hand.phase == .playing, let led = match.hand.currentTrick.first?.card.suit,
              let seat = viewerSeat, match.hand.hands[seat].contains(where: { $0.suit == led }) else { return nil }
        return led
    }

    /// What naming `suit` as trump would do to the hand: "keep 4 · draw 2". Only while the human is
    /// choosing trump; it counts the human's own cards and reveals nothing about the stock.
    public func trumpPreview(for suit: Suit) -> String? {
        guard match.hand.phase == .choosingTrump, isHumanTurn, let seat = viewerSeat else { return nil }
        let kept = match.hand.hands[seat].filter { $0.suit == suit }.count
        return "keep \(kept) · draw \(min(6 - kept, match.hand.stock.count))"
    }

    /// The dealer's special bidding rights, shown only when it is the human's turn to bid as dealer.
    public var auctionContext: String? {
        let auction = match.hand.auction
        guard match.hand.phase == .bidding, isHumanTurn, auction.dealer == viewerSeat else { return nil }
        if auction.isNineAndOut { return "A 9 and out stands, and the dealer may not match it: pass." }
        if let high = auction.highestBid { return "As dealer you may match the high bid of \(high)." }
        return "Everyone passed, so as dealer you must bid at least 2."
    }

    /// The most trumps a hand holds: the thirteen of the suit.
    public static let trumpTallyCap = 13

    /// One more trump played, as the player counts it; stops at thirteen. Only once trump is named.
    public func tallyTrump() {
        guard match.hand.trump != nil else { return }
        trumpTally = min(trumpTally + 1, Self.trumpTallyCap)
    }

    /// Takes back a mis-tapped tally mark; never below zero.
    public func untallyTrump() { trumpTally = max(trumpTally - 1, 0) }

    /// Marks `seat` as out of trump, or clears the mark. Only once trump is named.
    public func toggleOutOfTrump(_ seat: Int) {
        guard match.hand.trump != nil else { return }
        if outOfTrump.remove(seat) == nil { outOfTrump.insert(seat) }
    }

    /// The two taps being shown by the table, once per install, the first time trump is named (N61).
    @Published public private(set) var tallyDemo: TallyDemo?
    private var tallyDemoLeft: [TallyDemo] = []

    /// Starts the tally demo if trump is named and this install has never seen it. The flag is saved at once, so
    /// a demo cut short never comes back.
    public func beginTallyDemoIfDue() {
        guard match.hand.trump != nil, !settings.hasSeenTallyDemo, tallyDemo == nil else { return }
        settings.hasSeenTallyDemo = true
        tallyDemoLeft = TallyDemo.steps(opponent: seat(at: 1))
        advanceTallyDemo()
    }

    /// The demo's next step, or its end. Only the table's pulse and caption move; no mark or badge is made.
    public func advanceTallyDemo() {
        tallyDemo = tallyDemoLeft.isEmpty ? nil : tallyDemoLeft.removeFirst()
    }

    /// The player's tally and marks belong to one hand.
    private func clearTrumpTally() {
        trumpTally = 0
        outOfTrump = []
    }

    public func nextHand() {
        TableTrace.log("next hand asked")
        perform { try match.startNextHand(deck: Self.deck()) }
        revealedSeat = nil
        lastHumanAction = nil
        notice = nil
        clearTrumpTally()
    }
    /// A fresh match in `mode`, or in the current mode when none is given (Play again keeps it).
    public func newGame(mode: PlayMode? = nil) {
        TableTrace.log("new game")
        if let practice {
            self.mode = .solo
            revealedSeat = nil
            perform { match = try Match(deck: practice.deal.deck(), dealer: 3) }
            dealerDraw = nil
            recordedCurrentMatch = false
            finalPerformance = nil
            lastHumanAction = nil
            notice = nil
            clearTrumpTally()
            return
        }
        let draw = DealerDraw.draw(from: Self.deck())
        if let mode { self.mode = mode }
        revealedSeat = nil
        perform { match = try Match(deck: Self.deck(), dealer: draw.dealer) }
        dealerDraw = draw
        recordedCurrentMatch = false
        finalPerformance = nil
        lastHumanAction = nil
        notice = nil
        clearTrumpTally()
    }

    /// Applies a rule action. Returns true when the engine accepted it; a save failure afterwards is
    /// reported through `saveError` and does not make the action any less accepted.
    @discardableResult
    private func perform(_ action: () throws -> Void) -> Bool {
        do {
            try action()
        } catch {
            TableTrace.log("refused: \(error)")
            errorMessage = Self.message(for: error)
            return false
        }
        errorMessage = nil
        refusal = nil
        dealerDraw = nil   // the first action puts the draw away
        hint = nil
        explanation = nil
        persist()
        recordMatchIfFinished()
        if match.hand.phase == .finished { captureArchive(match, recovered: false) }
        revision += 1
        return true
    }

    /// Rule errors in the words a player would use.
    nonisolated public static func message(for error: Error) -> String {
        switch error {
        case HandError.mustFollowSuit: "You must follow suit: play a card of the suit that was led if you have one."
        case HandError.mustLeadTrump: "The bidder opens the hand with trump: lead a trump."
        case HandError.cardNotHeld: "That card is not in your hand."
        case HandError.wrongPhase, RuleError.auctionComplete: "That move does not fit this part of the hand."
        case HandError.notBidWinner: "Only the player who won the bid chooses trump."
        case RuleError.outOfTurn: "It is not your turn yet."
        case RuleError.invalidBid: "A bid must beat the high bid, and the dealer must bid at least two if everyone passes."
        case RuleError.forbiddenNineAndOut: "9 and out is not allowed while your score is below zero."
        case MatchError.matchFinished: "The match is over. Start a new game to keep playing."
        case MatchError.handInProgress: "Finish this hand before dealing the next one."
        default: "That move could not be completed."
        }
    }

    private func persistSettings() {
        guard let settingsURL else { return }
        do { try SettingsStore.write(settings, to: settingsURL) }
        catch { saveError = "Could not save your settings. \(error.localizedDescription)" }
    }

    private func persistHistory() {
        guard let historyURL else { return }
        do { try MatchHistoryStore.write(records, to: historyURL) }
        catch { saveError = "Could not save your match history. \(error.localizedDescription)" }
    }

    public func persist() {
        guard let saveURL else { return }
        do {
            try MatchSave.write(match, to: saveURL)
            try JSONEncoder().encode(mode).write(to: Self.modeURL(beside: saveURL), options: .atomic)
        }
        catch { saveError = "Could not save this game. Your current game is still open. \(error.localizedDescription)" }
    }

    /// Writes the game, settings and history again from the state already in memory.
    public func retrySave() {
        saveError = nil
        persist()
        persistSettings()
        persistHistory()
    }

    /// The play mode's file sits beside the game's; the rules engine's save format stays as it is.
    nonisolated static func modeURL(beside saveURL: URL) -> URL {
        saveURL.deletingLastPathComponent().appendingPathComponent("game-mode.json")
    }

    /// The saved game's mode; solo when the file is missing (a save from before pass and play) or unreadable.
    nonisolated static func readMode(beside saveURL: URL) -> PlayMode {
        (try? JSONDecoder().decode(PlayMode.self, from: Data(contentsOf: modeURL(beside: saveURL)))) ?? .solo
    }

    public static func deck() -> [Card] {
        Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }.shuffled()
    }

    public static func loadDefault() -> GameModel {
        loadDefault(in: FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CatchFive", isDirectory: true))
    }

    /// Loads the saved game, settings and history from `directory`, creating it if needed.
    public static func loadDefault(in directory: URL) -> GameModel {
        let url = directory.appendingPathComponent("game.json")
        let settingsURL = directory.appendingPathComponent("settings.json")
        let historyURL = directory.appendingPathComponent("history.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        var notices: [String] = []
        // Settings that cannot be read are set aside, not silently replaced: replacing them would sign the
        // player out and, through the login gate, discard their match.
        var settings = Settings()
        if FileManager.default.fileExists(atPath: settingsURL.path) {
            do { settings = try SettingsStore.read(from: settingsURL) } catch {
                notices.append(setAside(settingsURL, as: "settings-corrupt.json", what: "Your settings", error: error))
            }
        }
        let records = MatchHistoryStore.readSettingAsideCorruption(at: historyURL)
        let start = freshMatch()
        let fresh = GameModel(match: start.match, saveURL: url, settings: settings, settingsURL: settingsURL,
                              records: records, historyURL: historyURL, archiveDirectory: directory.appendingPathComponent("hand-archive", isDirectory: true))
        fresh.dealerDraw = start.draw
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let restored = GameModel(match: try MatchSave.read(from: url), mode: readMode(beside: url), saveURL: url, settings: settings, settingsURL: settingsURL,
                                         records: records, historyURL: historyURL, archiveDirectory: directory.appendingPathComponent("hand-archive", isDirectory: true))
                restored.errorMessage = notices.first
                return restored
            } catch {
                notices.append(setAside(url, as: "game-corrupt.json", what: "Your previous game", error: error))
            }
        }
        fresh.errorMessage = notices.isEmpty ? nil : notices.joined(separator: " ")
        return fresh
    }

    /// Moves an unreadable file out of the way and says exactly what happened, so the message never claims a
    /// rescue that failed; if it cannot be moved, the file will be replaced and the message says so.
    private static func setAside(_ url: URL, as name: String, what: String, error: Error) -> String {
        let aside = url.deletingLastPathComponent().appendingPathComponent(name)
        try? FileManager.default.removeItem(at: aside)
        do {
            try FileManager.default.moveItem(at: url, to: aside)
            return "\(what) could not be read, so it was kept as \(name) and fresh defaults are in use. \(error.localizedDescription)"
        } catch {
            return "\(what) could not be read and could not be set aside, so it will be replaced. \(error.localizedDescription)"
        }
    }
}
