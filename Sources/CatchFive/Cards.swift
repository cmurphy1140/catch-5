public enum Suit: String, CaseIterable, Codable, Sendable {
    case clubs, diamonds, hearts, spades
}

public enum Rank: Int, CaseIterable, Codable, Sendable {
    case two = 2, three, four, five, six, seven, eight, nine, ten, jack, queen, king, ace

    public var gameValue: Int {
        switch self {
        case .ten: 10
        case .jack: 1
        case .queen: 2
        case .king: 3
        case .ace: 4
        default: 0
        }
    }
}

public struct Card: Hashable, Codable, Sendable {
    public let suit: Suit
    public let rank: Rank

    public init(_ suit: Suit, _ rank: Rank) {
        self.suit = suit
        self.rank = rank
    }

    /// Plain words for explanations: "queen of hearts".
    public var name: String {
        let rank: String
        switch self.rank {
        case .ace: rank = "ace"
        case .king: rank = "king"
        case .queen: rank = "queen"
        case .jack: rank = "jack"
        default: rank = ["two", "three", "four", "five", "six", "seven", "eight", "nine", "ten"][self.rank.rawValue - 2]
        }
        return "\(rank) of \(suit.rawValue)"
    }
}

public enum RuleError: Error, Equatable {
    case invalidTrick, invalidSeat, outOfTurn, invalidBid, auctionComplete
    case invalidScoring, forbiddenNineAndOut
}
