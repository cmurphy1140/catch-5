public enum HandPhase: Sendable {
    case bidding, choosingTrump, playing, finished
}

public struct CompletedTrick: Sendable {
    public let plays: [Play]
    public let winner: Int
}

public enum HandError: Error, Equatable {
    case invalidDeck, wrongPhase, notBidWinner, cardNotHeld, mustFollowSuit
}

public struct Hand: Sendable {
    public private(set) var phase: HandPhase = .bidding
    public private(set) var auction: Auction
    public private(set) var hands: [[Card]] = [[], [], [], []]
    public private(set) var stock: [Card]
    public private(set) var discarded: [Card] = []
    public private(set) var trump: Suit?
    public private(set) var nextSeat: Int?
    public private(set) var currentTrick: [Play] = []
    public private(set) var completedTricks: [CompletedTrick] = []
    public private(set) var captured: [[Card]] = [[], []]
    public private(set) var result: HandScore?

    /// Supply a shuffled deck for play or a fixed deck for repeatable tests.
    public init(deck: [Card], dealer: Int) throws {
        auction = try Auction(dealer: dealer)
        guard deck.count == 52, Set(deck).count == 52 else { throw HandError.invalidDeck }
        stock = deck
        for _ in 0..<2 {
            for offset in 1...4 {
                let seat = (dealer + offset) % 4
                hands[seat].append(contentsOf: stock.prefix(3))
                stock.removeFirst(3)
            }
        }
        nextSeat = auction.nextSeat
    }

    public mutating func bid(seat: Int, amount: Int?) throws {
        guard phase == .bidding else { throw HandError.wrongPhase }
        try auction.act(seat: seat, bid: amount)
        nextSeat = auction.nextSeat
        if nextSeat == nil {
            phase = .choosingTrump
            nextSeat = auction.winner
        }
    }
    public mutating func chooseTrump(seat: Int, suit: Suit) throws {
        guard phase == .choosingTrump else { throw HandError.wrongPhase }
        guard seat == auction.winner else { throw HandError.notBidWinner }
        trump = suit
        for offset in 1...4 {
            let player = (auction.dealer + offset) % 4
            discarded.append(contentsOf: hands[player].filter { $0.suit != suit })
            hands[player].removeAll { $0.suit != suit }
            let needed = 6 - hands[player].count
            hands[player].append(contentsOf: stock.prefix(needed))
            stock.removeFirst(needed)
        }
        phase = .playing
        nextSeat = seat
    }
    public mutating func play(seat: Int, card: Card) throws {
        guard phase == .playing else { throw HandError.wrongPhase }
        guard seat == nextSeat else { throw RuleError.outOfTurn }
        guard let index = hands[seat].firstIndex(of: card) else { throw HandError.cardNotHeld }
        guard legalMoves(seat: seat).contains(card) else { throw HandError.mustFollowSuit }
        // Work on a copy so even a failed trick/scoring validation leaves the hand untouched.
        var updated = self
        updated.hands[seat].remove(at: index)
        updated.currentTrick.append(Play(seat: seat, card: card))
        updated.nextSeat = (seat + 1) % 4
        if updated.currentTrick.count == 4 { try updated.finishTrick() }
        self = updated
    }

    private mutating func finishTrick() throws {
        guard let trump, let bidder = auction.winner else { throw HandError.wrongPhase }
        let winner = try trickWinner(currentTrick, trump: trump)
        completedTricks.append(CompletedTrick(plays: currentTrick, winner: winner))
        captured[winner % 2].append(contentsOf: currentTrick.map(\.card))
        currentTrick = []
        nextSeat = winner
        if completedTricks.count == 6 {
            result = try scoreHand(captured: captured, trump: trump, bidder: bidder % 2)
            phase = .finished
            nextSeat = nil
        }
    }
    public func legalMoves(seat: Int) -> [Card] {
        guard phase == .playing, nextSeat == seat, (0..<4).contains(seat) else { return [] }
        return legalCards(in: hands[seat], led: currentTrick.first?.card.suit)
    }
}
