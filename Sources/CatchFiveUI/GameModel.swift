import CatchFive
import Combine
import Foundation

@MainActor
public final class GameModel: ObservableObject {
    @Published public private(set) var match: Match
    @Published public private(set) var revision = 0
    @Published public var errorMessage: String?
    /// A failed write of the game, settings or history. The move it followed was accepted and stands;
    /// `retrySave()` writes the same state again and never replays anything.
    @Published public var saveError: String?
    /// The computer strategy's advice for the human seat, shown on request and cleared by the next action.
    @Published public private(set) var hint: Advice?
    /// Why a card on the table or in the last trick was played; toggled by tapping it.
    @Published public private(set) var explanation: String?
    /// A one-line note about something that happened without a tap, such as the discard after trump.
    @Published public private(set) var notice: String?
    /// Why the human's last refused tap was refused, in the player's words; cleared by the next accepted action.
    @Published public private(set) var refusal: String?
    /// The human's most recent accepted action, for the undo toast and haptics; nil after undo or a new hand.
    @Published public private(set) var lastHumanAction: PlayerAction?
    @Published public var settings: Settings { didSet { persistSettings() } }
    /// Every finished match, oldest first.
    @Published public private(set) var records: [MatchRecord]
    /// The human's record for a finished match, computed once when it is recorded or restored.
    @Published public private(set) var finalPerformance: SeatPerformance?
    private let saveURL: URL?
    private let settingsURL: URL?
    private let historyURL: URL?
    /// Set once the current match has been recorded, and when a match is restored already finished.
    private var recordedCurrentMatch: Bool
    /// Supplies the date of a record; injectable for tests.
    public var now: () -> Date = Date.init

    public init(match: Match, saveURL: URL? = nil, settings: Settings = Settings(), settingsURL: URL? = nil,
                records: [MatchRecord] = [], historyURL: URL? = nil) {
        self.match = match
        self.saveURL = saveURL
        self.settings = settings
        self.settingsURL = settingsURL
        self.records = records
        self.historyURL = historyURL
        recordedCurrentMatch = match.winner != nil
        if match.winner != nil { finalPerformance = try? match.performance(forSeat: 0) }
    }

    public var statistics: Statistics { Statistics(records) }

    /// The finished hand's outcome in the player's order: contract, arithmetic, defenders, deciding rules.
    var lastHandOutcome: HandOutcome? {
        let history = match.history
        guard let last = history.last else { return nil }
        let before = history.count > 1 ? history[history.count - 2].scores : [0, 0]
        return HandOutcome(summary: last, before: before, names: seatNames)
    }

    /// Every play of the finished hand alongside the standard strategy's choice; nil before the hand is scored.
    public func handReview() -> HandReview? {
        guard match.hand.phase == .finished else { return nil }
        return try? HandReview(match: match)
    }

    private func recordMatchIfFinished() {
        guard match.winner != nil, !recordedCurrentMatch else { return }
        recordedCurrentMatch = true
        let performance = (try? match.performance(forSeat: 0)) ?? SeatPerformance(plays: 0, playsAgreed: 0, bids: 0, bidsMade: 0)
        finalPerformance = performance
        records.append(MatchRecord(date: now(), scores: match.scores, winner: match.winner ?? 0, hands: match.history.count,
                                   difficulty: settings.difficulty, humanBids: performance.bids, humanBidsMade: performance.bidsMade,
                                   humanPlays: performance.plays, humanPlaysAgreed: performance.playsAgreed))
        persistHistory()
    }

    public var isHumanTurn: Bool { match.winner == nil && match.hand.nextSeat == 0 }
    public var seatNames: [String] { settings.seatNames }

    /// True once something has happened this match and nobody has won yet; drives the menu's Continue button.
    public var matchInProgress: Bool { match.actionCount > 0 && match.winner == nil }

    /// The login screen's one write: the trimmed name becomes seat 0's name as well.
    public func signIn(name: String, portrait: Portrait, difficulty: Difficulty) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        settings.playerName = trimmed
        settings.seatNames[0] = trimmed
        settings.playerPortrait = portrait
        settings.difficulty = difficulty
    }

    /// One VoiceOver sentence for a seat tile: name, direction, call or card count, dealer, to act.
    public func seatSummary(for seat: Int) -> String {
        let hand = match.hand
        var parts = [seatNames[seat]]
        if seat != 0 { parts.append(Cast.seatWords[seat]) }
        if hand.phase == .bidding { parts.append(latestCall(for: seat) ?? "waiting") }
        else if hand.auction.winner == seat { parts.append("bidder, \(hand.hands[seat].count) cards") }
        else { parts.append("\(hand.hands[seat].count) cards") }
        if hand.auction.dealer == seat { parts.append("dealer") }
        if hand.nextSeat == seat, match.winner == nil { parts.append("to act") }
        return parts.joined(separator: ", ")
    }

    /// The hand as shown: trumps first, highest to lowest, then the other suits in a fixed order.
    public var humanCards: [Card] {
        let trump = match.hand.trump
        return match.hand.hands[0].sorted { a, b in
            if (a.suit == trump) != (b.suit == trump) { return a.suit == trump }
            if a.suit != b.suit { return Suit.allCases.firstIndex(of: a.suit)! < Suit.allCases.firstIndex(of: b.suit)! }
            return a.rank.rawValue > b.rank.rawValue
        }
    }

    public func send(_ action: PlayerAction) {
        guard isHumanTurn else { return }
        notice = nil
        let discards = discardCount(for: action)
        if perform({ try match.apply(action, seat: 0) }) {
            notice = discards.map(discardNotice)
            lastHumanAction = action
        }
    }
    public func stepComputer() {
        guard match.winner == nil, let seat = match.hand.nextSeat, seat != 0 else { return }
        var discards: Int?
        perform {
            let view = try PlayerView(match: match, seat: seat)
            guard let action = ComputerPlayer.decide(view, difficulty: settings.difficulty) else { return }
            discards = discardCount(for: action)
            try match.apply(action, seat: seat)
        }
        if let discards { notice = discardNotice(discards) }
    }

    /// How many of the human's cards leave when `action` names trump; nil for any other action.
    private func discardCount(for action: PlayerAction) -> Int? {
        guard case let .chooseTrump(suit) = action, match.hand.phase == .choosingTrump else { return nil }
        return match.hand.hands[0].filter { $0.suit != suit }.count
    }
    private func discardNotice(_ count: Int) -> String {
        count == 0 ? "You kept all six cards." : "You discarded \(count) and drew \(count)."
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
        return winner == play.seat ? base + " and took the trick" : base
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
    public var canUndo: Bool { match.undoPoint(forSeat: 0) != nil }

    /// Take back the human's latest action in this hand and every computer reply after it.
    public func undo() {
        guard let point = match.undoPoint(forSeat: 0) else { return }
        perform { match = try match.rewound(toActionCount: point) }
        lastHumanAction = nil
        notice = nil
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

    /// True until the player has dismissed the tutorial once.
    public var needsRulesIntroduction: Bool { !settings.hasSeenRules }
    public func markRulesSeen() { settings.hasSeenRules = true }

    /// Ask the computer strategy what it would do from seat 0 and why.
    public func showHint() {
        guard isHumanTurn, let view = try? PlayerView(match: match, seat: 0) else { return }
        hint = ComputerPlayer.advise(view)
    }

    /// Plain words for why `play` happened, from the strategy's point of view at that moment.
    /// `trickIndex` names a completed trick; nil means the card is still on the table.
    public func explanation(for play: Play, inLastTrick: Bool, trickIndex: Int? = nil) -> String? {
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
        if play.seat != 0, settings.difficulty == .easy {
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
        explanation = explanation == text ? nil : text
    }

    public func allows(_ action: PlayerAction) -> Bool {
        guard isHumanTurn else { return false }
        var copy = match
        return (try? copy.apply(action, seat: 0)) != nil
    }

    /// Nil when the engine would accept `action` from the human right now; otherwise the reason it would
    /// not, in the player's words. Validates on a copy, so the match and its action count never change.
    public func validationMessage(for action: PlayerAction) -> String? {
        guard match.winner == nil else { return Self.message(for: MatchError.matchFinished) }
        guard isHumanTurn else {
            return match.hand.nextSeat.map { "Wait for \(seatNames[$0])." } ?? "This hand is over."
        }
        var copy = match
        do {
            try copy.apply(action, seat: 0)
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

    /// The dealer's special bidding rights, shown only when it is the human's turn to bid as dealer.
    public var auctionContext: String? {
        let auction = match.hand.auction
        guard match.hand.phase == .bidding, isHumanTurn, auction.dealer == 0 else { return nil }
        if auction.isNineAndOut { return "As dealer you may match 9 and out; matching makes you the bidder." }
        if let high = auction.highestBid { return "As dealer you may match the high bid of \(high)." }
        return "Everyone passed, so as dealer you must bid at least 2."
    }

    public func nextHand() {
        perform { try match.startNextHand(deck: Self.deck()) }
        lastHumanAction = nil
        notice = nil
    }
    public func newGame() {
        perform { match = try Match(deck: Self.deck(), dealer: 3) }
        recordedCurrentMatch = false
        finalPerformance = nil
        lastHumanAction = nil
        notice = nil
    }

    /// Applies a rule action. Returns true when the engine accepted it; a save failure afterwards is
    /// reported through `saveError` and does not make the action any less accepted.
    @discardableResult
    private func perform(_ action: () throws -> Void) -> Bool {
        do {
            try action()
        } catch {
            errorMessage = Self.message(for: error)
            return false
        }
        errorMessage = nil
        refusal = nil
        hint = nil
        explanation = nil
        persist()
        recordMatchIfFinished()
        revision += 1
        return true
    }

    /// Rule errors in the words a player would use.
    public static func message(for error: Error) -> String {
        switch error {
        case HandError.mustFollowSuit: "You must follow suit: play a card of the suit that was led if you have one."
        case HandError.cardNotHeld: "That card is not in your hand."
        case HandError.wrongPhase, RuleError.auctionComplete: "That move does not fit this part of the hand."
        case HandError.notBidWinner: "Only the player who won the bid chooses trump."
        case RuleError.outOfTurn: "It is not your turn yet."
        case RuleError.invalidBid: "A bid must beat the high bid, and the dealer must bid at least two if everyone passes."
        case RuleError.forbiddenNineAndOut: "9 and out is not allowed while your score is below zero."
        case MatchError.matchFinished: "The match is over. Start a new game to keep playing."
        case MatchError.handInProgress: "Finish this hand before dealing the next one."
        default: "That action could not be completed: \(error)"
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
        do { try MatchSave.write(match, to: saveURL) }
        catch { saveError = "Could not save this game. Your current game is still open. \(error.localizedDescription)" }
    }

    /// Writes the game, settings and history again from the state already in memory.
    public func retrySave() {
        saveError = nil
        persist()
        persistSettings()
        persistHistory()
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
        let settings = (try? SettingsStore.read(from: settingsURL)) ?? Settings()
        let historyURL = directory.appendingPathComponent("history.json")
        let records = MatchHistoryStore.readSettingAsideCorruption(at: historyURL)
        // The generated deck is always a valid, unique 52-card deck.
        let fresh = GameModel(match: try! Match(deck: deck(), dealer: 3), saveURL: url, settings: settings, settingsURL: settingsURL,
                              records: records, historyURL: historyURL)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return GameModel(match: try MatchSave.read(from: url), saveURL: url, settings: settings, settingsURL: settingsURL,
                                 records: records, historyURL: historyURL)
            }
        } catch {
            fresh.errorMessage = "Your previous game could not be restored. A new game is ready. \(error.localizedDescription)"
        }
        return fresh
    }
}
