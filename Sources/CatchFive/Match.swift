public enum MatchError: Error, Equatable {
    case handInProgress, matchFinished
}

public struct HandSummary: Sendable {
    public let number: Int
    public let dealer: Int
    public let bidder: Int
    public let bid: Int
    public let isNineAndOut: Bool
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
    public mutating func bidNineAndOut(seat: Int) throws {
        guard winner == nil else { throw MatchError.matchFinished }
        guard (0..<4).contains(seat) else { throw RuleError.invalidSeat }
        guard scores[seat % 2] >= 0 else { throw RuleError.forbiddenNineAndOut }
        try hand.bid(seat: seat, amount: 9, nineAndOut: true)
        actions.append(.nineAndOut(seat: seat))
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
                                 bidder: bidder % 2, bid: hand.auction.isNineAndOut ? .nineAndOut : .points(amount))
        scores = outcome.scores
        winner = outcome.winner
        history.append(HandSummary(number: handNumber, dealer: hand.auction.dealer,
                                   bidder: bidder, bid: amount, isNineAndOut: hand.auction.isNineAndOut, result: result, scores: scores))
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

extension Match {
    public var actionCount: Int { actions.count }

    /// Rebuilds a match from the same first deal by replaying only the first `count` accepted actions.
    public func rewound(toActionCount count: Int) throws -> Match {
        guard count <= actions.count else { throw MatchError.handInProgress }
        return try Match.replaying(deck: initialDeck, dealer: initialDealer, actions: Array(actions.prefix(count)))
    }

    /// The action count to rewind to so that `seat`'s latest action in the current hand is taken back,
    /// along with everything after it. Nil once the hand is scored or when the seat has not acted this hand.
    public func undoPoint(forSeat seat: Int) -> Int? {
        guard winner == nil, hand.phase != .finished else { return nil }
        for (index, action) in actions.enumerated().reversed() {
            switch action {
            case .nextHand: return nil
            case let .bid(actor, _), let .nineAndOut(actor), let .trump(actor, _), let .play(actor, _):
                if actor == seat { return index }
            }
        }
        return nil
    }

    static func replaying(deck: [Card], dealer: Int, actions: [SavedAction]) throws -> Match {
        var match = try Match(deck: deck, dealer: dealer)
        for action in actions { try action.apply(to: &match) }
        return match
    }
}
