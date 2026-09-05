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
    // Middle cards promise no High, Low, Jack or Five, so nothing justifies even a two.
    let cards = [Card(.clubs, .nine), Card(.spades, .eight)]
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

@Test func computerUsesLowestWinningCardAgainstOpponentWhenNothingIsAtStake() {
    let cards = [Card(.hearts, .ace), Card(.hearts, .queen), Card(.hearts, .two)]
    let trick = [Play(seat: 3, card: Card(.hearts, .nine))]
    #expect(ComputerPlayer.decide(view(cards: cards, trick: trick)) == .play(Card(.hearts, .queen)))
}

@Test func computerSpendsTheAceToCaptureTheFive() {
    // Partner was forced to drop the five under an opponent's king; the ace is worth spending.
    let cards = [Card(.hearts, .ace), Card(.hearts, .queen), Card(.hearts, .two)]
    let trick = [Play(seat: 1, card: Card(.hearts, .king)), Play(seat: 2, card: Card(.hearts, .five)),
                 Play(seat: 3, card: Card(.hearts, .six))]
    #expect(ComputerPlayer.decide(view(cards: cards, trick: trick)) == .play(Card(.hearts, .ace)))
}

@Test func computerDumpsTheTrickWhenItIsWorthlessAndNoTrumpIsFree() {
    // Void in clubs, the trick holds no points: keep both trumps rather than trump a nothing trick.
    let cards = [Card(.hearts, .eight), Card(.hearts, .seven), Card(.spades, .four)]
    let trick = [Play(seat: 1, card: Card(.clubs, .nine)), Play(seat: 2, card: Card(.clubs, .three)),
                 Play(seat: 3, card: Card(.clubs, .eight))]
    #expect(ComputerPlayer.decide(view(cards: cards, trick: trick)) == .play(Card(.spades, .four)))
    // The same position with a ten on the table is worth the cheaper trump.
    let tenTrick = [Play(seat: 1, card: Card(.clubs, .ten)), Play(seat: 2, card: Card(.clubs, .three)),
                    Play(seat: 3, card: Card(.clubs, .eight))]
    #expect(ComputerPlayer.decide(view(cards: cards, trick: tenTrick)) == .play(Card(.hearts, .seven)))
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

struct RepeatableRandom: RandomNumberGenerator {
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

@Test func computerLeadsHighestTrumpButKeepsTheFiveBack() {
    let cards = [Card(.hearts, .ace), Card(.hearts, .five), Card(.clubs, .ten)]
    #expect(ComputerPlayer.decide(view(cards: cards)) == .play(Card(.hearts, .ace)))
    let fiveOnlyTrump = [Card(.hearts, .five), Card(.clubs, .ten), Card(.spades, .king)]
    #expect(ComputerPlayer.decide(view(cards: fiveOnlyTrump)) == .play(Card(.spades, .king)))
    #expect(ComputerPlayer.decide(view(cards: [Card(.hearts, .five)])) == .play(Card(.hearts, .five)))
}

@Test func computerSeesPublicAuctionCalls() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var match = try Match(deck: deck, dealer: 3)
    try match.bid(seat: 0, amount: 4)
    let view = try PlayerView(match: match, seat: 1)
    #expect(view.calls == [AuctionCall(seat: 0, bid: .points(4))])
}

@Test func estimateRanksControlAndTheFiveAboveScatteredCards() {
    let strong = [Card(.spades, .ace), Card(.spades, .king), Card(.spades, .five), Card(.hearts, .two)]
    let weak = [Card(.clubs, .two), Card(.clubs, .three), Card(.hearts, .ace), Card(.diamonds, .king)]
    #expect(ComputerPlayer.estimate(strong, suit: .spades) > ComputerPlayer.estimate(weak, suit: .clubs))
    #expect(ComputerPlayer.estimate(strong, suit: .spades) > ComputerPlayer.estimate(strong, suit: .hearts))
    #expect(ComputerPlayer.estimate([Card(.hearts, .five), Card(.hearts, .ace)], suit: .hearts)
            > ComputerPlayer.estimate([Card(.hearts, .five), Card(.clubs, .ace)], suit: .hearts))
    #expect(ComputerPlayer.estimate([Card(.clubs, .ace)], suit: .hearts) == 0)
    #expect(ComputerPlayer.decide(view(cards: strong, phase: .bidding, highestBid: 3, bidder: 1)) == .bid(4))
}

/// Guards the bidding calibration: computers should compete for most hands and usually make their contract.
@Test func computerBiddingIsCompetitiveAndUsuallyMakesContract() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var hands = 0, made = 0, forcedDealerTwo = 0
    for seed in 1...200 {
        var random = RepeatableRandom(state: UInt64(seed))
        var match = try Match(deck: deck.shuffled(using: &random), dealer: seed % 4)
        while match.winner == nil {
            if match.hand.phase == .finished { try match.startNextHand(deck: deck.shuffled(using: &random)); continue }
            let seat = try #require(match.hand.nextSeat)
            // A dealer who must open because the other three passed is the forced two.
            if match.hand.phase == .bidding, seat == match.hand.auction.dealer, match.hand.auction.highestBid == nil {
                forcedDealerTwo += 1
            }
            try match.apply(try #require(ComputerPlayer.decide(PlayerView(match: match, seat: seat))), seat: seat)
        }
        for summary in match.history {
            hands += 1
            if summary.result.points[summary.bidder % 2] >= summary.bid { made += 1 }
        }
    }
    #expect(Double(made) / Double(hands) >= 0.7)
    #expect(Double(forcedDealerTwo) / Double(hands) <= 0.35)
}
