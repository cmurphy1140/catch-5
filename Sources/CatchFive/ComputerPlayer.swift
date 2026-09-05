/// Only this player's cards and public information cross the strategy boundary.
public struct PlayerView: Sendable {
    public let seat: Int
    public let cards: [Card]
    public let phase: HandPhase
    public let nextSeat: Int?
    public let dealer: Int
    public let highestBid: Int?
    public let bidder: Int?
    public let trump: Suit?
    public let trick: [Play]
}

extension PlayerView {
    public init(match: Match, seat: Int) throws {
        guard (0..<4).contains(seat) else { throw RuleError.invalidSeat }
        let hand = match.hand
        self.init(seat: seat, cards: hand.hands[seat], phase: hand.phase,
                  nextSeat: match.winner == nil ? hand.nextSeat : nil,
                  dealer: hand.auction.dealer, highestBid: hand.auction.highestBid,
                  bidder: hand.auction.winner, trump: hand.trump, trick: hand.currentTrick)
    }
}

public enum PlayerAction: Equatable, Sendable {
    case nineAndOut
    case bid(Int?)
    case chooseTrump(Suit)
    case play(Card)
}

public enum ComputerPlayer {
    public static func decide(_ view: PlayerView) -> PlayerAction? {
        guard view.nextSeat == view.seat else { return nil }
        switch view.phase {
        case .bidding: return .bid(bidAmount(view))
        case .choosingTrump: return .chooseTrump(preferredSuit(view.cards))
        case .playing: return chooseCard(view).map(PlayerAction.play)
        case .finished: return nil
        }
    }

    private static func preferredSuit(_ cards: [Card]) -> Suit {
        // Fixed suit order makes equal-strength choices repeatable.
        Suit.allCases.max { strength(cards, suit: $0) < strength(cards, suit: $1) } ?? .clubs
    }

    private static func strength(_ cards: [Card], suit: Suit) -> Int {
        cards.filter { $0.suit == suit }.reduce(0) { total, card in
            total + 2 + (card.rank.rawValue >= Rank.jack.rawValue ? 2 : 0)
                + (card.rank == .five ? 2 : 0)
        }
    }

    private static func bidAmount(_ view: PlayerView) -> Int? {
        if let bidder = view.bidder, bidder % 2 == view.seat % 2 { return nil }
        let needed = view.highestBid.map { $0 + (view.seat == view.dealer ? 0 : 1) } ?? 2
        let confidence = min(5, strength(view.cards, suit: preferredSuit(view.cards)) / 3)
        if needed <= confidence { return needed }
        if view.seat == view.dealer && view.highestBid == nil { return 2 }
        return nil
    }

    private static func chooseCard(_ view: PlayerView) -> Card? {
        guard let trump = view.trump else { return nil }
        let legal = legalCards(in: view.cards, led: view.trick.first?.card.suit)
        guard let lead = view.trick.first else {
            // Lead a high card to gain control; this is a baseline heuristic.
            return legal.max { rank($0, led: trump, trump: trump) < rank($1, led: trump, trump: trump) }
        }
        let current = view.trick.max { rank($0.card, led: lead.card.suit, trump: trump)
            < rank($1.card, led: lead.card.suit, trump: trump) }!
        let partnerWinning = current.seat % 2 == view.seat % 2
        if partnerWinning && view.trick.count == 3 {
            return legal.max { value($0, trump: trump) < value($1, trump: trump) }
        }
        if !partnerWinning {
            let winning = legal.filter { rank($0, led: lead.card.suit, trump: trump)
                > rank(current.card, led: lead.card.suit, trump: trump) }
            if let cheapest = winning.min(by: { rank($0, led: lead.card.suit, trump: trump)
                < rank($1, led: lead.card.suit, trump: trump) }) { return cheapest }
        }
        return legal.min { value($0, trump: trump) < value($1, trump: trump) }
    }

    private static func rank(_ card: Card, led: Suit, trump: Suit) -> Int {
        let tier = card.suit == trump ? 200 : (card.suit == led ? 100 : 0)
        return tier + card.rank.rawValue
    }

    private static func value(_ card: Card, trump: Suit) -> Int {
        let bonus = card.suit == trump ? (card.rank == .five ? 500 : 30) : 0
        return bonus + card.rank.gameValue * 10 + card.rank.rawValue
    }
}

extension Match {
    /// Human and computer actions use the same checked entry points.
    public mutating func apply(_ action: PlayerAction, seat: Int) throws {
        switch action {
        case .nineAndOut: try bidNineAndOut(seat: seat)
        case let .bid(amount): try bid(seat: seat, amount: amount)
        case let .chooseTrump(suit): try chooseTrump(seat: seat, suit: suit)
        case let .play(card): try play(seat: seat, card: card)
        }
    }
}
