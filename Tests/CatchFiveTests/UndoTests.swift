import Testing
@testable import CatchFive

private func playedMatch() throws -> Match {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var match = try Match(deck: deck, dealer: 3)
    try match.bid(seat: 0, amount: 9)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    for _ in 0..<5 {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    return match
}

@Test func rewoundMatchEqualsFreshReplay() throws {
    let match = try playedMatch()
    #expect(match.actionCount == 10)
    let whole = try match.rewound(toActionCount: match.actionCount)
    #expect(try MatchSave.encode(whole) == MatchSave.encode(match))
    let partial = try match.rewound(toActionCount: 5)
    #expect(partial.actionCount == 5)
    #expect(partial.hand.phase == .playing && partial.hand.currentTrick.isEmpty)
    #expect(throws: (any Error).self) { try match.rewound(toActionCount: 99) }
}

@Test func undoDropsHumanActionAndComputerReplies() throws {
    let match = try playedMatch()   // 4 bids, trump, seat 0's lead, three replies, then the winner's lead
    let point = try #require(match.undoPoint(forSeat: 0))
    #expect(point == 5)   // just before seat 0's opening lead
    let undone = try match.rewound(toActionCount: point)
    #expect(undone.hand.nextSeat == 0 && undone.hand.completedTricks.isEmpty && undone.hand.hands[0].count == 6)
    // Undoing again steps back to before the trump choice, then to before the bid.
    let trump = try #require(undone.undoPoint(forSeat: 0))
    #expect(trump == 4)
    let choosing = try undone.rewound(toActionCount: trump)
    #expect(choosing.hand.phase == .choosingTrump && choosing.hand.nextSeat == 0)
    #expect(choosing.undoPoint(forSeat: 0) == 0)
    #expect(try choosing.rewound(toActionCount: 0).hand.phase == .bidding)
}

@Test func undoUnavailableAcrossHandBoundaryAndAfterScoring() throws {
    var match = try playedMatch()
    while match.hand.phase == .playing {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    #expect(match.hand.phase == .finished)
    #expect(match.undoPoint(forSeat: 0) == nil)
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    try match.startNextHand(deck: deck)
    #expect(match.undoPoint(forSeat: 0) == nil)   // nothing of seat 0's in this hand yet
    try match.bid(seat: 1, amount: nil)
    #expect(match.undoPoint(forSeat: 1) == match.actionCount - 1)
}
