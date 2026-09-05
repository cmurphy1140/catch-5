import Testing
@testable import CatchFive

@Test func reviewReconstructsEveryPlayWithAdvice() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var random = RepeatableRandom(state: 21)
    var match = try Match(deck: deck.shuffled(using: &random), dealer: 0)
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.apply(try #require(ComputerPlayer.decide(PlayerView(match: match, seat: seat))), seat: seat)
    }
    let review = try HandReview(match: match)
    #expect(review.tricks.count == 6)
    #expect(review.tricks.allSatisfy { $0.plays.count == 4 })
    #expect(review.tricks.map(\.number) == Array(1...6))
    // Every seat played the standard strategy, so every play agrees with its own advice.
    for seat in 0..<4 { #expect(review.agreement(forSeat: seat) == (6, 6)) }
    #expect(review.tricks.flatMap(\.plays).allSatisfy { !$0.advice.reason.isEmpty })
}

@Test func performanceCountsHumanPlaysAndContractsAcrossHands() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var random = RepeatableRandom(state: 3)
    var match = try Match(deck: deck.shuffled(using: &random), dealer: 3)
    var humanPlays = 0, disagreed = 0
    while match.winner == nil {
        if match.hand.phase == .finished { try match.startNextHand(deck: deck.shuffled(using: &random)); continue }
        let seat = try #require(match.hand.nextSeat)
        let view = try PlayerView(match: match, seat: seat)
        var action = try #require(ComputerPlayer.decide(view))
        // Seat 0 plays its last legal card instead of the advised one whenever that differs.
        if seat == 0, case .play = action, let other = match.hand.legalMoves(seat: 0).last, action != .play(other) {
            action = .play(other); disagreed += 1
        }
        if seat == 0, case .play = action { humanPlays += 1 }
        try match.apply(action, seat: seat)
    }
    let performance = try match.performance(forSeat: 0)
    #expect(performance.plays == humanPlays)
    #expect(performance.playsAgreed == humanPlays - disagreed)
    #expect(performance.bids == match.history.filter { $0.bidder == 0 }.count)
    #expect(performance.bidsMade <= performance.bids)
    #expect(humanPlays == match.history.count * 6)
}

@Test func handSummaryKnowsWhetherTheContractWasMade() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var random = RepeatableRandom(state: 8)
    var match = try Match(deck: deck.shuffled(using: &random), dealer: 1)
    while match.history.count < 4, match.winner == nil {
        if match.hand.phase == .finished { try match.startNextHand(deck: deck.shuffled(using: &random)); continue }
        let seat = try #require(match.hand.nextSeat)
        try match.apply(try #require(ComputerPlayer.decide(PlayerView(match: match, seat: seat))), seat: seat)
    }
    #expect(!match.history.isEmpty)
    for summary in match.history {
        #expect(summary.contractMade == (summary.result.points[summary.bidder % 2] >= summary.bid))
    }
}
