import Testing
@testable import CatchFive

@Test func relativeHighAndLowBelongToCapturingTeams() throws {
    let result = try scoreHand(captured: [
        [Card(.hearts, .king), Card(.hearts, .jack), Card(.hearts, .five)],
        [Card(.hearts, .four), Card(.clubs, .ten)]
    ], trump: .hearts, bidder: 0)
    #expect(result.highTeam == 0)
    #expect(result.lowTeam == 1)
    #expect(result.jackTeam == 0)
    #expect(result.fiveTeam == 0)
    #expect(result.gameValues == [4, 10])
    #expect(result.gameTeam == 1)
    #expect(result.points == [7, 2])
}

@Test func missingJackAndFiveDoNotScoreAndGameTieGoesToBidder() throws {
    for bidder in [0, 1] {
        let result = try scoreHand(captured: [[Card(.clubs, .king)], [Card(.diamonds, .king)]],
                                   trump: .clubs, bidder: bidder)
        #expect(result.highTeam == 0)
        #expect(result.lowTeam == 0)
        #expect(result.jackTeam == nil)
        #expect(result.fiveTeam == nil)
        #expect(result.gameValues == [3, 3])
        #expect(result.gameTeam == bidder)
        #expect(result.points == (bidder == 0 ? [3, 0] : [2, 1]))
    }
}

@Test func offSuitScoringCardsOnlyCountTowardGame() throws {
    let result = try scoreHand(captured: [[Card(.spades, .jack), Card(.spades, .five)],
                                        [Card(.diamonds, .ace), Card(.clubs, .queen)]],
                               trump: .hearts, bidder: 0)
    #expect(result.points == [0, 1])
    #expect(result.gameValues == [1, 6])
    #expect(result.highTeam == nil)
    #expect(result.lowTeam == nil)
}

@Test func invalidCapturedCardsAreRejected() {
    #expect(throws: RuleError.invalidScoring) { try scoreHand(captured: [], trump: .clubs, bidder: 0) }
    #expect(throws: RuleError.invalidScoring) {
        try scoreHand(captured: [[Card(.clubs, .ace)], [Card(.clubs, .ace)]], trump: .clubs, bidder: 0)
    }
    #expect(throws: RuleError.invalidScoring) { try scoreHand(captured: [[], []], trump: .clubs, bidder: 2) }
}

@Test func successfulBidScoresAllPointsAndSetLosesBidAmount() throws {
    #expect(try settle(scores: [0, 0], points: [7, 2], bidder: 0, bid: .points(4)).scores == [7, 2])
    #expect(try settle(scores: [1, 0], points: [3, 6], bidder: 0, bid: .points(4)).scores == [-3, 6])
    #expect(try settle(scores: [0, -2], points: [1, 8], bidder: 1, bid: .points(5)).scores == [1, 6])
}

@Test func twentyFiveAndSimultaneousFinish() throws {
    #expect(try settle(scores: [24, 24], points: [2, 7], bidder: 0, bid: .points(2)).winner == 0)
    #expect(try settle(scores: [24, 24], points: [7, 2], bidder: 1, bid: .points(2)).winner == 1)
    #expect(try settle(scores: [20, 24], points: [3, 6], bidder: 0, bid: .points(4)).winner == 1)
    #expect(try settle(scores: [0, 0], points: [3, 6], bidder: 0, bid: .points(3)).winner == nil)
    #expect(try settle(scores: [23, 0], points: [2, 7], bidder: 0, bid: .points(2)).winner == 0)
}

@Test func nineAndOutWinsOrLosesImmediately() throws {
    for bidder in [0, 1] {
        var all = [0, 0]
        all[bidder] = 9
        #expect(try settle(scores: [0, 0], points: all, bidder: bidder, bid: .nineAndOut).winner == bidder)
        for collected in 0..<9 {
            var points = [0, 0]
            points[bidder] = collected
            #expect(try settle(scores: [24, 24], points: points, bidder: bidder,
                               bid: .nineAndOut).winner == 1 - bidder)
        }
    }
    #expect(throws: RuleError.forbiddenNineAndOut) {
        try settle(scores: [-1, 0], points: [9, 0], bidder: 0, bid: .nineAndOut)
    }
    #expect(try settle(scores: [0, 0], points: [9, 0], bidder: 0, bid: .points(9)).winner == nil)
}

@Test func invalidSettlementRejected() {
    for points in [[10, 0], [5, 5], [-1, 1], [1]] {
        #expect(throws: RuleError.invalidScoring) {
            try settle(scores: [0, 0], points: points, bidder: 0, bid: .points(2))
        }
    }
    #expect(throws: RuleError.invalidScoring) {
        try settle(scores: [], points: [2, 7], bidder: 0, bid: .points(2))
    }
    #expect(throws: RuleError.invalidScoring) {
        try settle(scores: [0, 0], points: [2, 7], bidder: 2, bid: .points(2))
    }
    #expect(throws: RuleError.invalidBid) {
        try settle(scores: [0, 0], points: [2, 7], bidder: 0, bid: .points(1))
    }
}
