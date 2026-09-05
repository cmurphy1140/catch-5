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
    private let saveURL: URL?

    public init(match: Match, saveURL: URL? = nil) {
        self.match = match
        self.saveURL = saveURL
    }

    public var isHumanTurn: Bool { match.winner == nil && match.hand.nextSeat == 0 }
    public var humanCards: [Card] { match.hand.hands[0] }
    public func send(_ action: PlayerAction) {
        guard isHumanTurn else { return }
        perform { try match.apply(action, seat: 0) }
    }
    public func stepComputer() {
        guard match.winner == nil, let seat = match.hand.nextSeat, seat != 0 else { return }
        perform {
            let view = try PlayerView(match: match, seat: seat)
            guard let action = ComputerPlayer.decide(view) else { return }
            try match.apply(action, seat: seat)
        }
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
        return "\(Self.seatNames[bidder]) bid \(auction.isNineAndOut ? "9 and out" : String(bid))"
    }

    public static let seatNames = ["You", "West", "Partner", "East"]

    /// Ask the computer strategy what it would do from seat 0 and why.
    public func showHint() {
        guard isHumanTurn, let view = try? PlayerView(match: match, seat: 0) else { return }
        hint = ComputerPlayer.advise(view)
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
            persist()
            revision += 1
        } catch {
            errorMessage = "That action could not be completed: \(error)"
        }
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
        // The generated deck is always a valid, unique 52-card deck.
        let fresh = GameModel(match: try! Match(deck: deck(), dealer: 3), saveURL: url)
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return GameModel(match: try MatchSave.read(from: url), saveURL: url)
            }
        } catch {
            fresh.errorMessage = "Your previous game could not be restored. A new game is ready. \(error.localizedDescription)"
        }
        return fresh
    }
}
