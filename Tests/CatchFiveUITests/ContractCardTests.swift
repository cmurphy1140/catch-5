import CatchFive
@testable import CatchFiveUI
import Testing

@Test func contractCallsKeepTheirSeatsWhenDisplayNamesRepeat() throws {
    var auction = try Auction(dealer: 0)
    try auction.act(seat: 1, bid: 2)
    try auction.act(seat: 2, bid: nil)
    try auction.act(seat: 3, bid: 4)
    try auction.act(seat: 0, bid: nil)
    let summary = try #require(ContractCard.Summary(auction: auction, trump: .diamonds,
        names: Array(repeating: "Alexandria Montgomery", count: 4), scores: [7, 12], ourTeam: 1))
    #expect(Set(summary.calls.map(\.id)).count == 4)
    #expect(summary.calls.map(\.id) == [1, 2, 3, 0])
    #expect(summary.calls.map(\.words) == ["2", "Pass", "4", "Pass"])
    #expect(summary.calls.map(\.won) == [false, false, true, false])
    #expect(summary.us == 12 && summary.them == 7)
    #expect(summary.bidderSeat == 3 && summary.bidder == "Alexandria Montgomery")
    #expect(summary.bid == 4 && !summary.isNineAndOut && summary.trump == .diamonds)
}

@Test func contractSummaryDistinguishesNineAndOutFromAnOrdinaryNine() throws {
    for nineAndOut in [false, true] {
        var auction = try Auction(dealer: 2)
        try auction.act(seat: 3, bid: 9, nineAndOut: nineAndOut)
        try auction.act(seat: 0, bid: nil)
        try auction.act(seat: 1, bid: nil)
        try auction.act(seat: 2, bid: nil)
        let summary = try #require(ContractCard.Summary(auction: auction, trump: .spades,
            names: Settings.familySeatNames, scores: [0, 24], ourTeam: 0))
        #expect(summary.bidderSeat == 3 && summary.bidder == "Diane")
        #expect(summary.bid == 9 && summary.isNineAndOut == nineAndOut)
        #expect(summary.calls.map(\.id) == [3, 0, 1, 2])
        #expect(summary.calls[0].words == (nineAndOut ? "9 and out" : "9"))
        #expect(summary.headline == (nineAndOut ? "Diane took the bid at nine and out" : "Diane took the bid at 9"))
        #expect(summary.trump == .spades)
    }
}

@Test func contractSummaryWaitsForTheAuctionToFinish() throws {
    var auction = try Auction(dealer: 0)
    try auction.act(seat: 1, bid: 4)
    #expect(ContractCard.Summary(auction: auction, trump: nil, names: Settings.defaultSeatNames,
        scores: [0, 0], ourTeam: 0) == nil)
}

@MainActor @Test func contractPlaqueKeepsTheWinningSeatAcrossRosterAndNameChanges() throws {
    for roster in Settings.Opponents.allCases {
        var settings = Settings()
        settings.seat(roster)
        settings.renameSeat(1, to: "Alexandria Montgomery")
        var match = try Match(deck: GameModel.deck(), dealer: 0)
        try match.bid(seat: 1, amount: 4)
        try match.bid(seat: 2, amount: nil)
        try match.bid(seat: 3, amount: nil)
        try match.bid(seat: 0, amount: nil)
        try match.chooseTrump(seat: 1, suit: .clubs)
        let model = GameModel(match: match, settings: settings)
        let contract = try #require(ContractPlaque.contract(in: model))
        #expect(contract.bidderSeat == 1)
        #expect(contract.bidder == "Alexandria Montgomery")
        #expect(contract.portrait == Cast.opponent(at: 1)?.portrait)
        #expect(ContractPlaque.spoken(contract, tally: 2) == "Alexandria Montgomery bid 4, clubs are trump, 2 trump played")
        let plaque = ContractPlaque.onTable(model, contract: contract, width: 120)
        plaque.onAdd()
        plaque.onAdd()
        plaque.onTakeBack()
        #expect(model.trumpTally == 1)
    }
}
