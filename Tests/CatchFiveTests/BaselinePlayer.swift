@testable import CatchFive

/// Frozen copy of the computer player as merged in PR #2 (2026-09-04).
/// It exists only as a fixed opponent for `StrategyBenchmark`; do not improve it.
enum BaselinePlayer {
    static func decide(_ view: PlayerView) -> PlayerAction? {
        guard view.nextSeat == view.seat else { return nil }
        switch view.phase {
        case .bidding: return .bid(bidAmount(view))
        case .choosingTrump: return .chooseTrump(preferredSuit(view.cards))
        case .playing: return chooseCard(view).map(PlayerAction.play)
        case .finished: return nil
        }
    }

    private static func preferredSuit(_ cards: [Card]) -> Suit {
        Suit.allCases.max { estimate(cards, suit: $0) < estimate(cards, suit: $1) } ?? .clubs
    }

    private static func estimate(_ cards: [Card], suit: Suit) -> Double {
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
        points += Double(6 - trumps.count) * 0.1
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
