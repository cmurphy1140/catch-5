public enum MatchError: Error, Equatable {
    case handInProgress, matchFinished
}

public struct HandSummary: Sendable {
    public let number: Int
    public let dealer: Int
    public let bidder: Int
    public let bid: Int
    public let result: HandScore
    public let scores: [Int]
}

/// Owns the whole game. All player actions pass through the current Hand's rules.
public struct Match: Sendable {
    public private(set) var hand: Hand
    public private(set) var scores = [0, 0]
    public private(set) var winner: Int?
    public private(set) var history: [HandSummary] = []
    public private(set) var handNumber = 1
    let initialDeck: [Card]
    let initialDealer: Int
    private(set) var actions: [SavedAction] = []

    public init(deck: [Card], dealer: Int) throws {
        hand = try Hand(deck: deck, dealer: dealer)
        initialDeck = deck
        initialDealer = dealer
    }

    public mutating func bid(seat: Int, amount: Int?) throws {
        guard winner == nil else { throw MatchError.matchFinished }
        try hand.bid(seat: seat, amount: amount)
        actions.append(.bid(seat: seat, amount: amount))
    }
    public mutating func chooseTrump(seat: Int, suit: Suit) throws {
        guard winner == nil else { throw MatchError.matchFinished }
        try hand.chooseTrump(seat: seat, suit: suit)
        actions.append(.trump(seat: seat, suit: suit))
    }
    public mutating func play(seat: Int, card: Card) throws {
        guard winner == nil else { throw MatchError.matchFinished }
        var updated = self
        try updated.hand.play(seat: seat, card: card)
        if updated.hand.phase == .finished { try updated.recordHand() }
        updated.actions.append(.play(seat: seat, card: card))
        self = updated
    }

    private mutating func recordHand() throws {
        guard let result = hand.result, let bidder = hand.auction.winner,
              let amount = hand.auction.highestBid else { throw HandError.wrongPhase }
        let outcome = try settle(scores: scores, points: result.points,
                                 bidder: bidder % 2, bid: .points(amount))
        scores = outcome.scores
        winner = outcome.winner
        history.append(HandSummary(number: handNumber, dealer: hand.auction.dealer,
                                   bidder: bidder, bid: amount, result: result, scores: scores))
    }
    public mutating func startNextHand(deck: [Card]) throws {
        guard winner == nil else { throw MatchError.matchFinished }
        guard hand.phase == .finished else { throw MatchError.handInProgress }
        let next = try Hand(deck: deck, dealer: (hand.auction.dealer + 1) % 4)
        hand = next
        handNumber += 1
        actions.append(.nextHand(deck: deck))
    }
}
