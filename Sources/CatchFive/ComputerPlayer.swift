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
    public let calls: [AuctionCall]

    public init(seat: Int, cards: [Card], phase: HandPhase, nextSeat: Int?, dealer: Int,
                highestBid: Int?, bidder: Int?, trump: Suit?, trick: [Play], calls: [AuctionCall] = []) {
        self.seat = seat
        self.cards = cards
        self.phase = phase
        self.nextSeat = nextSeat
        self.dealer = dealer
        self.highestBid = highestBid
        self.bidder = bidder
        self.trump = trump
        self.trick = trick
        self.calls = calls
    }
}

extension PlayerView {
    public init(match: Match, seat: Int) throws {
        guard (0..<4).contains(seat) else { throw RuleError.invalidSeat }
        let hand = match.hand
        self.init(seat: seat, cards: hand.hands[seat], phase: hand.phase,
                  nextSeat: match.winner == nil ? hand.nextSeat : nil,
                  dealer: hand.auction.dealer, highestBid: hand.auction.highestBid,
                  bidder: hand.auction.winner, trump: hand.trump, trick: hand.currentTrick,
                  calls: hand.auction.calls)
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
        Suit.allCases.max { estimate(cards, suit: $0) < estimate(cards, suit: $1) } ?? .clubs
    }

    /// Expected hand points if `suit` were trump, judged before the discard and refill.
    /// Weights are playtesting heuristics, not derived probabilities.
    static func estimate(_ cards: [Card], suit: Suit) -> Double {
        let trumps = cards.filter { $0.suit == suit }.map(\.rank.rawValue).sorted()
        guard let top = trumps.last, let bottom = trumps.first else { return 0 }
        let control = trumps.filter { $0 >= Rank.king.rawValue }.count
        var points = 0.0
        points += [Rank.ace.rawValue: 1.0, Rank.king.rawValue: 0.75, Rank.queen.rawValue: 0.45][top] ?? 0.2
        points += [Rank.two.rawValue: 1.0, Rank.three.rawValue: 0.75, Rank.four.rawValue: 0.5][bottom] ?? 0.2
        if trumps.contains(Rank.jack.rawValue) { points += control > 0 ? 0.8 : 0.4 }
        if trumps.contains(Rank.five.rawValue) {
            points += 2.5 + Double(control) * 0.75 + Double(trumps.count - 1) * 0.25
        } else if control >= 2 {
            points += 0.75
        }
        points += 0.5 + Double(max(0, trumps.count - 2)) * 0.3
        points += Double(6 - trumps.count) * 0.1 // Refill may bring more trumps.
        return points
    }

    private static func bidAmount(_ view: PlayerView) -> Int? {
        if let bidder = view.bidder, bidder % 2 == view.seat % 2 { return nil }
        let needed = view.highestBid.map { $0 + (view.seat == view.dealer ? 0 : 1) } ?? 2
        let confidence = Int((estimate(view.cards, suit: preferredSuit(view.cards)) - 0.5).rounded(.down))
        if needed <= min(confidence, 9) { return needed }
        if view.seat == view.dealer && view.highestBid == nil { return 2 }
        return nil
    }

    private static func chooseCard(_ view: PlayerView) -> Card? {
        guard let trump = view.trump else { return nil }
        let legal = legalCards(in: view.cards, led: view.trick.first?.card.suit)
        guard let lead = view.trick.first else {
            // Lead a high card to gain control, but never expose the trump five when another lead exists.
            let leads = legal.filter { $0 != Card(trump, .five) }
            return (leads.isEmpty ? legal : leads)
                .max { rank($0, led: trump, trump: trump) < rank($1, led: trump, trump: trump) }
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
