import Testing
@testable import CatchFive

private func matchDeck(_ number: Int) -> [Card] {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let rotation = (number * 7) % 52
    return Array(deck[rotation...]) + Array(deck[..<rotation])
}

private func prepare(_ match: inout Match, bid: Int = 2) throws {
    let bidder = (match.hand.auction.dealer + 1) % 4
    try match.bid(seat: bidder, amount: bid)
    for offset in 1...3 { try match.bid(seat: (bidder + offset) % 4, amount: nil) }
    try match.chooseTrump(seat: bidder, suit: Suit.allCases[match.handNumber % 4])
}

private func playCards(_ count: Int, in match: inout Match) throws {
    for _ in 0..<count {
        let seat = try #require(match.hand.nextSeat)
        let card = try #require(match.hand.legalMoves(seat: seat).first)
        try match.play(seat: seat, card: card)
    }
}

@Test func matchRejectsPrematureRedeal() throws {
    var match = try Match(deck: matchDeck(1), dealer: 3)
    let cards = match.hand.hands
    #expect(throws: MatchError.handInProgress) { try match.startNextHand(deck: matchDeck(2)) }
    #expect(match.hand.hands == cards)
    #expect(match.handNumber == 1)
    #expect(match.scores == [0, 0])
}

@Test func matchScoresOnlyAfterLastCardAndOnlyOnce() throws {
    var match = try Match(deck: matchDeck(1), dealer: 3)
    try prepare(&match)
    try playCards(23, in: &match)
    #expect(match.scores == [0, 0])
    #expect(match.history.isEmpty)
    try playCards(1, in: &match)
    #expect(match.scores == [2, 7])
    let summary = try #require(match.history.first)
    #expect(summary.number == 1)
    #expect(summary.dealer == 3)
    #expect(summary.bidder == 0)
    #expect(summary.bid == 2)
    #expect(summary.result.gameValues == [24, 16])
    #expect(summary.scores == [2, 7])
    #expect(throws: HandError.wrongPhase) { try match.play(seat: 0, card: Card(.clubs, .two)) }
    #expect(match.history.count == 1)
    #expect(match.scores == [2, 7])
}

@Test func nextHandRotatesDealerAndRetainsScores() throws {
    var match = try Match(deck: matchDeck(1), dealer: 3)
    try prepare(&match)
    try playCards(24, in: &match)
    #expect(throws: HandError.invalidDeck) { try match.startNextHand(deck: []) }
    #expect(match.handNumber == 1)
    #expect(match.hand.phase == .finished)
    try match.startNextHand(deck: matchDeck(2))
    #expect(match.handNumber == 2)
    #expect(match.hand.auction.dealer == 0)
    #expect(match.hand.nextSeat == 1)
    #expect(match.hand.phase == .bidding)
    #expect(match.scores == [2, 7])
    #expect(match.history.count == 1)
}

@Test func matchRejectsInvalidActionsWithoutChangingState() throws {
    var match = try Match(deck: matchDeck(1), dealer: 3)
    #expect(throws: RuleError.outOfTurn) { try match.bid(seat: 2, amount: 2) }
    #expect(throws: HandError.wrongPhase) { try match.chooseTrump(seat: 0, suit: .clubs) }
    #expect(match.hand.nextSeat == 0)
    #expect(match.hand.auction.highestBid == nil)
    #expect(match.history.isEmpty)
}

@Test func failedBidMakesNegativeMatchScore() throws {
    var match = try Match(deck: matchDeck(1), dealer: 3)
    try prepare(&match, bid: 4)
    try playCards(24, in: &match)
    #expect(match.scores == [-4, 7])
    #expect(match.winner == nil)
}

@Test func completeMatchConnectsBiddingTricksScoringAndVictory() throws {
    var match = try Match(deck: matchDeck(1), dealer: 3)
    let expectedScores = [[2, 7], [10, 5], [12, 12], [19, 14], [26, 16]]
    for number in 1...5 {
        if number > 1 { try match.startNextHand(deck: matchDeck(number)) }
        try prepare(&match)
        try playCards(24, in: &match)
        #expect(match.scores == expectedScores[number - 1])
        #expect(match.history.count == number)
        #expect(match.winner == (number == 5 ? 0 : nil))
    }
    #expect(throws: MatchError.matchFinished) { try match.startNextHand(deck: matchDeck(6)) }
    #expect(throws: MatchError.matchFinished) { try match.bid(seat: 0, amount: 2) }
    #expect(throws: MatchError.matchFinished) { try match.chooseTrump(seat: 0, suit: .clubs) }
    #expect(throws: MatchError.matchFinished) { try match.play(seat: 0, card: Card(.clubs, .ace)) }
    #expect(match.scores == [26, 16])
    #expect(match.history.count == 5)
}

@Test func specialBidFlowsThroughMatchAndSavedGame() throws {
    var match = try Match(deck: matchDeck(1), dealer: 3)
    try match.bidNineAndOut(seat: 0)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    match = try MatchSave.decode(MatchSave.encode(match))
    #expect(match.hand.auction.isNineAndOut)
    try match.chooseTrump(seat: 0, suit: .diamonds)
    try playCards(24, in: &match)
    #expect(match.winner == 1)
    #expect(match.history.first?.isNineAndOut == true)
    #expect(try MatchSave.decode(MatchSave.encode(match)).winner == 1)
}

@Test func negativeTeamCannotDeclareNineAndOut() throws {
    var match = try Match(deck: matchDeck(1), dealer: 3)
    try prepare(&match, bid: 4)
    try playCards(24, in: &match)
    try match.startNextHand(deck: matchDeck(2))
    try match.bid(seat: 1, amount: nil)
    #expect(throws: RuleError.forbiddenNineAndOut) { try match.bidNineAndOut(seat: 2) }
    #expect(match.hand.nextSeat == 2)
}
