import Testing
@testable import CatchFive

private let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }

private func startHand(dealer: Int = 3, trump: Suit = .hearts, cards: [Card] = deck) throws -> Hand {
    var hand = try Hand(deck: cards, dealer: dealer)
    let bidder = (dealer + 1) % 4
    try hand.bid(seat: bidder, amount: 2)
    for offset in 1...3 { try hand.bid(seat: (bidder + offset) % 4, amount: nil) }
    try hand.chooseTrump(seat: bidder, suit: trump)
    return hand
}

private func allCards(_ hand: Hand) -> [Card] {
    hand.hands.flatMap { $0 } + hand.stock + hand.discarded
        + hand.captured.flatMap { $0 } + hand.currentTrick.map(\.card)
}

@Test func dealSixEachInTwoPacketsStartingLeftOfDealer() throws {
    let hand = try Hand(deck: deck, dealer: 3)
    #expect(hand.hands.map(\.count) == [6, 6, 6, 6])
    #expect(hand.hands[0] == [Card(.clubs, .two), Card(.clubs, .three), Card(.clubs, .four),
                            Card(.clubs, .ace), Card(.diamonds, .two), Card(.diamonds, .three)])
    #expect(hand.stock.count == 28)
    #expect(Set(allCards(hand)).count == 52)
    #expect(hand.nextSeat == 0)
}

@Test func rejectInvalidDecks() {
    #expect(throws: HandError.invalidDeck) { try Hand(deck: [], dealer: 0) }
    #expect(throws: HandError.invalidDeck) { try Hand(deck: Array(repeating: deck[0], count: 52), dealer: 0) }
}

@Test func trumpSelectionRequiresFinishedAuctionAndWinningSeat() throws {
    var hand = try Hand(deck: deck, dealer: 3)
    #expect(throws: HandError.wrongPhase) { try hand.chooseTrump(seat: 0, suit: .clubs) }
    #expect(throws: HandError.wrongPhase) { try hand.play(seat: 0, card: deck[0]) }
    try hand.bid(seat: 0, amount: 4)
    try hand.bid(seat: 1, amount: nil)
    try hand.bid(seat: 2, amount: nil)
    try hand.bid(seat: 3, amount: 4)
    #expect(hand.phase == .choosingTrump)
    #expect(hand.nextSeat == 3)
    #expect(throws: HandError.notBidWinner) { try hand.chooseTrump(seat: 0, suit: .clubs) }
    #expect(throws: HandError.wrongPhase) { try hand.bid(seat: 3, amount: 5) }
    try hand.chooseTrump(seat: 3, suit: .clubs)
    #expect(hand.nextSeat == 3)
    #expect(hand.phase == .playing)
}

@Test func refillKeepsTrumpsAndDiscardsOnlyInitialNonTrumps() throws {
    let original = try Hand(deck: deck, dealer: 3)
    let hand = try startHand(trump: .clubs)
    #expect(hand.hands.map(\.count) == [6, 6, 6, 6])
    #expect(hand.discarded.count == 11)
    #expect(hand.stock.count == 17)
    #expect(hand.discarded.allSatisfy { $0.suit != .clubs })
    for seat in 0..<4 {
        #expect(original.hands[seat].filter { $0.suit == .clubs }.allSatisfy { hand.hands[seat].contains($0) })
    }
    #expect(allCards(hand).count == 52)
    #expect(Set(allCards(hand)).count == 52)
}

@Test func illegalPlayLeavesStateUnchanged() throws {
    var hand = try startHand()
    let before = hand.hands
    #expect(throws: RuleError.outOfTurn) { try hand.play(seat: 1, card: deck[0]) }
    #expect(throws: HandError.cardNotHeld) { try hand.play(seat: 0, card: Card(.clubs, .two)) }
    #expect(hand.hands == before)
    #expect(hand.currentTrick.isEmpty)
    #expect(hand.nextSeat == 0)
    #expect(hand.legalMoves(seat: 1).isEmpty)
    #expect(hand.legalMoves(seat: -1).isEmpty)
}

@Test func playMustFollowSuitAndWinningPlayerLeadsNext() throws {
    // Construct a deck with all 13 hearts first so each player retains hearts after refill.
    let ordered = deck.sorted { ($0.suit == .hearts ? 0 : 1) < ($1.suit == .hearts ? 0 : 1) }
    var hand = try startHand(cards: ordered)
    let lead = try #require(hand.hands[0].first { $0.suit == .hearts })
    try hand.play(seat: 0, card: lead)
    let offSuit = try #require(hand.hands[1].first { $0.suit != .hearts })
    let before = hand.hands
    #expect(throws: HandError.mustFollowSuit) { try hand.play(seat: 1, card: offSuit) }
    #expect(hand.hands == before)
    #expect(hand.nextSeat == 1)
    for seat in 1...3 {
        let card = try #require(hand.legalMoves(seat: seat).first)
        try hand.play(seat: seat, card: card)
    }
    let trick = try #require(hand.completedTricks.first)
    #expect(hand.nextSeat == trick.winner)
    #expect(hand.currentTrick.isEmpty)
    #expect(hand.captured[trick.winner % 2].count == 4)
}

@Test func completeHandsConserveCardsAndFinishAfterSixTricks() throws {
    // 208 deterministic deck rotations, covering every dealer and trump suit.
    for rotation in 0..<52 {
        let cards = Array(deck[rotation...]) + Array(deck[..<rotation])
        for dealer in 0..<4 {
            var hand = try startHand(dealer: dealer, trump: Suit.allCases[(rotation + dealer) % 4], cards: cards)
            for _ in 0..<24 {
                let seat = try #require(hand.nextSeat)
                let move = try #require(hand.legalMoves(seat: seat).first)
                try hand.play(seat: seat, card: move)
                #expect(allCards(hand).count == 52)
                #expect(Set(allCards(hand)).count == 52)
            }
            #expect(hand.phase == .finished)
            #expect(hand.nextSeat == nil)
            #expect(hand.completedTricks.count == 6)
            #expect(hand.hands.allSatisfy { $0.isEmpty })
            #expect(hand.captured.flatMap { $0 }.count == 24)
            let result = try #require(hand.result)
            #expect((1...9).contains(result.points.reduce(0, +)))
            #expect(throws: HandError.wrongPhase) { try hand.play(seat: 0, card: cards[0]) }
        }
    }
}
