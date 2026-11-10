import CatchFive
import Foundation

/// The only value the support transport can encode. Never stores a Match or another seat's view.
struct SupportContext: Codable, Equatable, Sendable {
    struct PublicPlay: Codable, Equatable, Sendable { let seat: Int; let card: String }
    struct PublicTrick: Codable, Equatable, Sendable { let plays: [PublicPlay]; let winner: Int }
    struct Call: Codable, Equatable, Sendable { let seat: Int; let amount: Int?; let nineAndOut: Bool }
    struct Outcome: Codable, Equatable, Sendable {
        let points: [Int]
        let gameValues: [Int]
        let scores: [Int]
        let winner: Int?
        let contractMade: Bool
        let bid: Int
        let bidder: Int
        let nineAndOut: Bool
        let highTeam: Int?
        let lowTeam: Int?
        let jackTeam: Int?
        let fiveTeam: Int?
        let gameTeam: Int
    }
    let seat: Int
    let phase: String
    let cards: [String]
    let nextSeat: Int?
    let dealer: Int
    let highestBid: Int?
    let bidder: Int?
    let trump: String?
    let scores: [Int]
    let calls: [Call]
    let trick: [PublicPlay]
    let completedTricks: [PublicTrick]
    let discardCounts: [Int]
    let legalOptions: [String]
    let recommendation: String?
    let outcome: Outcome?

    init(match: Match, seat: Int) throws {
        let view = try PlayerView(match: match, seat: seat)
        self.seat = view.seat
        phase = String(describing: view.phase)
        cards = view.cards.map(\.name)
        nextSeat = view.nextSeat
        dealer = view.dealer
        highestBid = view.highestBid
        bidder = view.bidder
        trump = view.trump?.rawValue
        scores = view.scores
        calls = view.calls.map { call in
            switch call.bid {
            case .points(let amount): Call(seat: call.seat, amount: amount, nineAndOut: false)
            case .nineAndOut: Call(seat: call.seat, amount: 9, nineAndOut: true)
            case nil: Call(seat: call.seat, amount: nil, nineAndOut: false)
            }
        }
        trick = view.trick.map { PublicPlay(seat: $0.seat, card: $0.card.name) }
        completedTricks = view.completedTricks.map { PublicTrick(plays: $0.plays.map { PublicPlay(seat: $0.seat, card: $0.card.name) }, winner: $0.winner) }
        discardCounts = view.discardCounts
        let candidates: [PlayerAction] = [.bid(nil)] + (2...9).map { .bid($0) } + [.nineAndOut]
            + Suit.allCases.map { .chooseTrump($0) } + view.cards.map { .play($0) }
        legalOptions = candidates.filter { action in
            var copy = match
            return (try? copy.apply(action, seat: seat)) != nil
        }.map(Self.describe)
        recommendation = view.nextSeat == seat ? ComputerPlayer.advise(view)?.reason : nil
        if let summary = match.history.last, summary.number == match.handNumber, view.phase == .finished {
            let result = summary.result
            outcome = Outcome(points: result.points, gameValues: result.gameValues, scores: summary.scores,
                              winner: match.winner, contractMade: summary.contractMade, bid: summary.bid,
                              bidder: summary.bidder, nineAndOut: summary.isNineAndOut,
                              highTeam: result.highTeam, lowTeam: result.lowTeam, jackTeam: result.jackTeam,
                              fiveTeam: result.fiveTeam, gameTeam: result.gameTeam)
        } else { outcome = nil }
    }

    @MainActor static func visible(in model: GameModel) -> SupportContext? {
        guard model.curtainSeat == nil, let seat = model.viewerSeat else { return nil }
        return try? SupportContext(match: model.match, seat: seat)
    }

    private static func describe(_ action: PlayerAction) -> String {
        switch action {
        case .bid(nil): "Pass"
        case let .bid(amount?): "Bid \(amount)"
        case .nineAndOut: "9 and out"
        case let .chooseTrump(suit): "Trump \(suit.rawValue)"
        case let .play(card): "Play \(card.name)"
        }
    }

    private func person(_ other: Int) -> String {
        if other == seat { return "You" }
        if other == (seat + 2) % 4 { return "Your partner" }
        return "An opponent"
    }

    func localAnswer(_ prompt: SupportPrompt) -> String {
        let team = seat % 2, other = 1 - team
        switch prompt {
        case .rules:
            switch phase {
            case "playing": return "Follow suit if you can. Otherwise any card is legal, including trump. Highest trump wins; without trump, the highest card of the led suit wins. The trick winner leads next."
            case "choosingTrump": return "The bid winner chooses trump. Everyone discards non-trumps and draws back to six cards. The bidder leads first and must lead trump if holding any."
            case "finished":
                if outcome?.nineAndOut == true {
                    return "9 and out ends the match: the bidding team wins only by collecting all nine points; fewer means the opponents win. Numeric scores stay unchanged. No normal bid bonus or penalty is added."
                }
                return "High, Low, Jack and Game each score 1; the trump Five scores 5. High and Low count only trumps actually played. Missing Jack or Five score nothing. Made bidders add captured points; missed bidders subtract their bid. Opponents keep their points."
            default: return "Bid 2–9 for points your team expects to capture. The dealer may match a normal high bid and must bid 2 if everyone passes. Nobody may match 9 and out. The winner chooses trump and leads trump if held. During play, follow suit when you can."
            }
        case .advice:
            return recommendation ?? (nextSeat.map { "\(person($0)) act next. Advice is available when it's your turn." } ?? "This hand is over. See the score breakdown before dealing again.")
        case .state:
            if let outcome {
                let bidders = outcome.bidder % 2 == team ? "Your team" : "Opponents"
                if outcome.nineAndOut {
                    let winner = outcome.winner == team ? "Your team wins" : "Opponents win"
                    return "\(winner): \(bidders.lowercased()) \(outcome.contractMade ? "made" : "missed") 9 and out. Your team captured \(outcome.points[team]) points; opponents \(outcome.points[other]). Numeric scores stay \(outcome.scores[team])–\(outcome.scores[other])."
                }
                return "Your team \(outcome.scores[team]), opponents \(outcome.scores[other]). \(bidders) \(outcome.contractMade ? "made" : "missed") the bid of \(outcome.bid). Hand points: \(outcome.points[team])–\(outcome.points[other]). Your score: \(scores[team]) → \(outcome.scores[team]); opponents: \(scores[other]) → \(outcome.scores[other]). Game values: \(outcome.gameValues[team])–\(outcome.gameValues[other]); Game goes to \(outcome.gameTeam == team ? "your team" : "opponents")."
            }
            let turn = nextSeat.map { "\(person($0)) \($0 == seat ? "act" : "acts") next." } ?? "The hand is over."
            let activity: String = switch phase {
            case "bidding": "Bidding is under way."
            case "choosingTrump": "The bid winner is choosing trump."
            case "playing": "Trump is \(trump ?? "not named"); \(completedTricks.count) of 6 tricks are complete."
            default: "This hand is finished."
            }
            return "\(activity) \(turn) Scores: your team \(scores[team]), opponents \(scores[other])." + (highestBid.map { " High bid: \($0)." } ?? "")
        }
    }
}

enum SupportPrompt: String, CaseIterable, Identifiable {
    case rules = "How do I play?"
    case state = "Explain this hand and score"
    case advice = "What should I bid or play?"
    var id: String { rawValue }

    static func starters(in context: SupportContext) -> [SupportPrompt] {
        context.phase == "finished" ? [.state, .rules] : [.advice, .state, .rules]
    }

    func question(in context: SupportContext) -> String {
        switch self {
        case .state: return context.phase == "finished" ? "How did we score?" : "What's happening now?"
        case .advice:
            switch context.phase {
            case "bidding": return "What should I bid?"
            case "choosingTrump": return "Which trump should I choose?"
            default: return "What should I play?"
            }
        case .rules:
            switch context.phase {
            case "bidding": return "How does bidding work?"
            case "choosingTrump": return "How does choosing trump work?"
            case "playing": return "Do I have to follow suit?"
            default: return "How does scoring work?"
            }
        }
    }
}

/// The opening page's helper (D120): company before a game, not a coach. Its starters are not about the game at first,
/// and offline it still has something to say.
enum FrontDesk {
    static let starters = ["Tell me a card-table joke", "Name our team for tonight", "What snack wins card night?", "OK, teach me Catch 5"]

    /// Plain chat the helper can answer without a server; nil when the question is about the game.
    static func chat(_ question: String) -> String? {
        let lower = question.lowercased()
        if lower.contains("joke") || lower.contains("funny") {
            return ["Why did the Jack get invited to every game? He's worth a point just for showing up.",
                    "My partner said they had my back. Then they trumped my Ace.",
                    "I'd tell you a joke about the Five of trump, but somebody always catches it."].randomElement()
        }
        if lower.contains("team") && lower.contains("name") {
            return ["The Trump Cards", "High, Low and Trouble", "Catch Us If You Can", "Nine and Out the Door"].randomElement().map { "How about: \($0)." }
        }
        if lower.contains("snack") || lower.contains("eat") || lower.contains("drink") {
            return "Anything one-handed that will not grease the cards. Pretzels are safe. Wings are a declaration of war."
        }
        if lower.contains("hello") || lower.contains("hi ") || lower == "hi" || lower.contains("hey") {
            return "Hello! Pull up a chair. Ask me for a joke, a team name, or how the game works."
        }
        return nil
    }

    static func localAnswer(_ question: String) -> String {
        if let chat = chat(question) { return chat }
        let lower = question.lowercased()
        if lower.contains("scor") || lower.contains("point") || lower.contains("win") {
            return "High, Low, Jack and Game each score 1; the trump Five scores 5, so nine points a hand. Make your bid and you add what you took; miss it and you lose the bid. First team to 25 wins."
        }
        if lower.contains("bid") {
            return "Bid 2 to 9: the points your team expects to take. Count your likely trumps first. An Ace or the Five of one suit with a couple of friends beside it is worth a bid; the dealer may match the high bid and must bid 2 if everyone passes."
        }
        if lower.contains("play") || lower.contains("teach") || lower.contains("rule") || lower.contains("catch") {
            return "Four players, two teams, six cards each. Bid for the points you think your team can take; the high bidder names trump, everyone trades in non-trumps, then six tricks are played. Follow suit if you can, highest trump wins. First to 25."
        }
        return "I'm offline right now, so I only know jokes, team names, snacks and the rules. Try one of those, or turn on online answers from the gear."
    }
}
