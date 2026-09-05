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
}

public enum RuleError: Error, Equatable {
    case invalidTrick, invalidSeat, outOfTurn, invalidBid, auctionComplete
    case invalidScoring, forbiddenNineAndOut
}
