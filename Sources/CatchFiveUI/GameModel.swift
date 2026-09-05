import CatchFive
import Combine
import Foundation

@MainActor
public final class GameModel: ObservableObject {
    @Published public private(set) var match: Match
    @Published public private(set) var revision = 0
    @Published public var errorMessage: String?
    /// The computer strategy's advice for the human seat, shown on request and cleared by the next action.
    @Published public private(set) var hint: Advice?
    /// Why a card on the table or in the last trick was played; toggled by tapping it.
    @Published public private(set) var explanation: String?
    /// A one-line note about something that happened without a tap, such as the discard after trump.
    @Published public private(set) var notice: String?
    @Published public var settings: Settings { didSet { persistSettings() } }
    private let saveURL: URL?
    private let settingsURL: URL?

    public init(match: Match, saveURL: URL? = nil, settings: Settings = Settings(), settingsURL: URL? = nil) {
        self.match = match
        self.saveURL = saveURL
        self.settings = settings
        self.settingsURL = settingsURL
    }

    public var isHumanTurn: Bool { match.winner == nil && match.hand.nextSeat == 0 }
    public var seatNames: [String] { settings.seatNames }

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
        let discards = discardCount(for: action)
        perform { try match.apply(action, seat: 0) }
        if errorMessage == nil { notice = discards.map(discardNotice) }
    }
    public func stepComputer() {
        guard match.winner == nil, let seat = match.hand.nextSeat, seat != 0 else { return }
        var discards: Int?
        perform {
            let view = try PlayerView(match: match, seat: seat)
            guard let action = ComputerPlayer.decide(view) else { return }
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

    /// Ask the computer strategy what it would do from seat 0 and why.
    public func showHint() {
        guard isHumanTurn, let view = try? PlayerView(match: match, seat: 0) else { return }
        hint = ComputerPlayer.advise(view)
    }

    /// Plain words for why `play` happened, from the strategy's point of view at that moment.
    public func explanation(for play: Play, inLastTrick: Bool) -> String? {
        let index = inLastTrick ? match.hand.completedTricks.count - 1 : nil
        guard let view = try? PlayerView(match: match, replaying: play, inCompletedTrick: index),
              let advice = ComputerPlayer.advise(view) else { return nil }
        // Advice reads "Play the X: reason"; keep only the reason after the colon.
        let reason = advice.reason.split(separator: ":", maxSplits: 1).last.map { $0.trimmingCharacters(in: .whitespaces) } ?? advice.reason
        let name = seatNames[play.seat]
        if play.seat == 0, advice.action != .play(play.card), case let .play(preferred) = advice.action {
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

    public func nextHand() { perform { try match.startNextHand(deck: Self.deck()) } }
    public func newGame() { perform { match = try Match(deck: Self.deck(), dealer: 3) } }

    private func perform(_ action: () throws -> Void) {
        do {
            try action()
            errorMessage = nil
            hint = nil
            explanation = nil
            notice = nil
            persist()
            revision += 1
        } catch {
            errorMessage = Self.message(for: error)
        }
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
        try? SettingsStore.write(settings, to: settingsURL)
    }

    public func persist() {
        guard let saveURL else { return }
        do { try MatchSave.write(match, to: saveURL) }
        catch { errorMessage = "Could not save this game. Your current game is still open. \(error.localizedDescription)" }
    }

    public static func deck() -> [Card] {
        Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }.shuffled()
    }

    public static func loadDefault() -> GameModel {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("CatchFive", isDirectory: true)
        let url = directory.appendingPathComponent("game.json")
        let settingsURL = directory.appendingPathComponent("settings.json")
        let settings = (try? SettingsStore.read(from: settingsURL)) ?? Settings()
        // The generated deck is always a valid, unique 52-card deck.
        let fresh = GameModel(match: try! Match(deck: deck(), dealer: 3), saveURL: url, settings: settings, settingsURL: settingsURL)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return GameModel(match: try MatchSave.read(from: url), saveURL: url, settings: settings, settingsURL: settingsURL)
            }
        } catch {
            fresh.errorMessage = "Your previous game could not be restored. A new game is ready. \(error.localizedDescription)"
        }
        return fresh
    }
}
