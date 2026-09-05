import Testing
@testable import CatchFive

@Test func dealerCanMatchPartnerOrOpponent() throws {
    for openingSeat in [0, 1, 2] {
        var auction = try Auction(dealer: 3)
        for seat in 0..<3 { try auction.act(seat: seat, bid: seat == openingSeat ? 4 : nil) }
        try auction.act(seat: 3, bid: 4)
        #expect(auction.winner == 3)
        #expect(auction.highestBid == 4)
        #expect(auction.nextSeat == nil)
    }
}

@Test func nonDealerMustRaiseAndInvalidActionDoesNotConsumeTurn() throws {
    var auction = try Auction(dealer: 3)
    try auction.act(seat: 0, bid: 4)
    #expect(throws: RuleError.invalidBid) { try auction.act(seat: 1, bid: 4) }
    #expect(auction.nextSeat == 1)
    try auction.act(seat: 1, bid: 5)
    #expect(auction.winner == 1)
}

@Test func dealerMustTakeTwoAfterPasses() throws {
    var auction = try Auction(dealer: 3)
    for seat in 0..<3 { try auction.act(seat: seat, bid: nil) }
    #expect(throws: RuleError.invalidBid) { try auction.act(seat: 3, bid: nil) }
    try auction.act(seat: 3, bid: 2)
    #expect(auction.winner == 3)
    #expect(auction.highestBid == 2)
    #expect(throws: RuleError.auctionComplete) { try auction.act(seat: 0, bid: 3) }
}

@Test func bidRangeAndTurnOrder() throws {
    var auction = try Auction(dealer: 1)
    #expect(auction.nextSeat == 2)
    #expect(throws: RuleError.outOfTurn) { try auction.act(seat: 0, bid: 2) }
    for bid in [-1, 0, 1, 10] {
        #expect(throws: RuleError.invalidBid) { try auction.act(seat: 2, bid: bid) }
    }
    try auction.act(seat: 2, bid: 9)
    try auction.act(seat: 3, bid: nil)
    try auction.act(seat: 0, bid: nil)
    try auction.act(seat: 1, bid: nil)
    #expect(auction.winner == 2)
    #expect(auction.highestBid == 9)
    #expect(auction.nextSeat == nil)
    #expect(throws: RuleError.invalidSeat) { try Auction(dealer: 4) }
}

@Test func nineAndOutOvercallsNineAndDealerCanMatch() throws {
    var auction = try Auction(dealer: 3)
    try auction.act(seat: 0, bid: 9)
    try auction.act(seat: 1, bid: 9, nineAndOut: true)
    #expect(throws: RuleError.invalidBid) { try auction.act(seat: 2, bid: 9, nineAndOut: true) }
    try auction.act(seat: 2, bid: nil)
    #expect(throws: RuleError.invalidBid) { try auction.act(seat: 3, bid: 9) }
    try auction.act(seat: 3, bid: 9, nineAndOut: true)
    #expect(auction.winner == 3)
    #expect(auction.isNineAndOut)
}

@Test func auctionRecordsEverySeatCallInOrder() throws {
    var auction = try Auction(dealer: 3)
    try auction.act(seat: 0, bid: nil)
    try auction.act(seat: 1, bid: 3)
    #expect(throws: RuleError.invalidBid) { try auction.act(seat: 2, bid: 3) }
    try auction.act(seat: 2, bid: 9, nineAndOut: true)
    try auction.act(seat: 3, bid: nil)
    #expect(auction.calls == [
        AuctionCall(seat: 0, bid: nil),
        AuctionCall(seat: 1, bid: .points(3)),
        AuctionCall(seat: 2, bid: .nineAndOut),
        AuctionCall(seat: 3, bid: nil),
    ])
    #expect(auction.calls.first { $0.seat == 1 }?.bid == .points(3))
}
