import Testing
@testable import CatchFive

private func view(cards: [Card], phase: HandPhase = .playing, seat: Int = 0,
                  dealer: Int = 3, highestBid: Int? = nil, bidder: Int? = nil,
                  trick: [Play] = []) -> PlayerView {
    PlayerView(seat: seat, cards: cards, phase: phase, nextSeat: seat,
               dealer: dealer, highestBid: highestBid, bidder: bidder,
               trump: .hearts, trick: trick)
}

@Test func computerPassesWeakHandButDealerTakesForcedTwo() {
    let cards = [Card(.clubs, .two), Card(.spades, .three)]
    #expect(ComputerPlayer.decide(view(cards: cards, phase: .bidding)) == .bid(nil))
    #expect(ComputerPlayer.decide(view(cards: cards, phase: .bidding, dealer: 0)) == .bid(2))
}

@Test func computerRaisesWithStrongSuitAndChoosesIt() {
    let cards = [Card(.spades, .ace), Card(.spades, .king), Card(.spades, .jack),
                 Card(.spades, .five), Card(.clubs, .two), Card(.diamonds, .three)]
    #expect(ComputerPlayer.decide(view(cards: cards, phase: .bidding, highestBid: 3, bidder: 1)) == .bid(4))
    #expect(ComputerPlayer.decide(view(cards: cards, phase: .choosingTrump)) == .chooseTrump(.spades))
    #expect(ComputerPlayer.decide(view(cards: cards, phase: .bidding, highestBid: 3, bidder: 2)) == .bid(nil))
    #expect(ComputerPlayer.decide(view(cards: cards, phase: .bidding, dealer: 0, highestBid: 3, bidder: 1)) == .bid(3))
}

@Test func computerFollowsSuitInsteadOfTrumping() {
    let cards = [Card(.hearts, .ace), Card(.clubs, .two)]
    let trick = [Play(seat: 3, card: Card(.clubs, .king))]
    #expect(ComputerPlayer.decide(view(cards: cards, trick: trick)) == .play(Card(.clubs, .two)))
}

@Test func computerUsesLowestWinningCardAgainstOpponent() {
    let cards = [Card(.hearts, .ace), Card(.hearts, .queen), Card(.hearts, .two)]
    let trick = [Play(seat: 3, card: Card(.hearts, .jack))]
    #expect(ComputerPlayer.decide(view(cards: cards, trick: trick)) == .play(Card(.hearts, .queen)))
}

@Test func computerFeedsFiveToPartnerWhenLastToPlay() {
    let cards = [Card(.hearts, .five), Card(.hearts, .two)]
    let trick = [Play(seat: 1, card: Card(.hearts, .king)),
                 Play(seat: 2, card: Card(.hearts, .ace)),
                 Play(seat: 3, card: Card(.hearts, .three))]
    #expect(ComputerPlayer.decide(view(cards: cards, trick: trick)) == .play(Card(.hearts, .five)))
}

@Test func computerPreservesFiveWhenItCannotWin() {
    let cards = [Card(.hearts, .five), Card(.hearts, .three)]
    let trick = [Play(seat: 3, card: Card(.hearts, .ace))]
    #expect(ComputerPlayer.decide(view(cards: cards, trick: trick)) == .play(Card(.hearts, .three)))
}

@Test func computerDoesNotActOutsideItsTurn() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let match = try Match(deck: deck, dealer: 3)
    #expect(ComputerPlayer.decide(try PlayerView(match: match, seat: 1)) == nil)
    #expect(throws: RuleError.invalidSeat) { try PlayerView(match: match, seat: 4) }
}

@Test func changingHiddenCardsDoesNotChangeComputerDecision() throws {
    var deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let first = try Match(deck: deck, dealer: 3)
    // Seat 0 gets positions 0...2 and 12...14. Swap an opponent card with stock.
    deck.swapAt(3, 40)
    let second = try Match(deck: deck, dealer: 3)
    let a = try PlayerView(match: first, seat: 0)
    let b = try PlayerView(match: second, seat: 0)
    #expect(a.cards == b.cards)
    #expect(ComputerPlayer.decide(a) == ComputerPlayer.decide(b))
}

private struct RepeatableRandom: RandomNumberGenerator {
    var state: UInt64
    mutating func next() -> UInt64 {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return state
    }
}

@Test func computersCompleteShuffledMatchesThroughRealRules() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    for seed in 1...24 {
        var random = RepeatableRandom(state: UInt64(seed))
        var match = try Match(deck: deck.shuffled(using: &random), dealer: seed % 4)
        for _ in 0..<10000 {
            if match.winner != nil { break }
            if match.hand.phase == .finished {
                try match.startNextHand(deck: deck.shuffled(using: &random))
                continue
            }
            let seat = try #require(match.hand.nextSeat)
            let action = try #require(ComputerPlayer.decide(PlayerView(match: match, seat: seat)))
            try match.apply(action, seat: seat)
        }
        let winner = try #require(match.winner)
        #expect(match.scores[winner] >= 25)
        #expect(match.history.count >= 3)
        let restored = try MatchSave.decode(MatchSave.encode(match))
        #expect(restored.winner == winner)
        #expect(restored.scores == match.scores)
    }
}
