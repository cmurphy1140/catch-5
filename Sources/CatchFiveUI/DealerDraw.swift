import CatchFive

/// How the first dealer is chosen: each seat draws a card and the highest deals. Equal ranks go by suit,
/// clubs lowest and spades highest, so one draw always settles it. The drawn cards are shown once and go
/// back into the deck; the match itself starts from a fresh shuffle with the chosen dealer.
struct DealerDraw: Equatable {
    /// Seat 0's card first, then seats 1, 2 and 3.
    let cards: [Card]
    let dealer: Int

    static func draw(from deck: [Card]) -> DealerDraw {
        let cards = Array(deck.prefix(4))
        let dealer = cards.indices.max { ranking(cards[$0]) < ranking(cards[$1]) } ?? 3
        return DealerDraw(cards: cards, dealer: dealer)
    }

    /// Rank first, then suit in the order clubs, diamonds, hearts, spades.
    static func ranking(_ card: Card) -> Int {
        card.rank.rawValue * 4 + (Suit.allCases.firstIndex(of: card.suit) ?? 0)
    }

    /// "Rue draws the king of spades and deals."
    func sentence(names: [String]) -> String {
        let who = dealer == 0 ? "You draw" : "\(names[dealer]) draws"
        return "\(who) the \(cards[dealer].name) and deal\(dealer == 0 ? "" : "s")."
    }
}
