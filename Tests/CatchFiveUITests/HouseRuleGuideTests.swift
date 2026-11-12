import CatchFive
@testable import CatchFiveUI
import Testing

@Test func ruleGuidePreservesCanonicalTextAndMapsEveryReplayRule() throws {
    let canonical = RulesText.sections.flatMap(\.paragraphs)
    #expect(Set(HouseRuleGuide.entries.map(\.id)).count == HouseRuleGuide.entries.count)
    for entry in HouseRuleGuide.entries {
        #expect(!entry.example.isEmpty)
        #expect(entry.paragraphs.allSatisfy { canonical.contains($0) })
        #expect(HouseRuleGuide.entry(id: entry.id)?.title == entry.title)
    }
    for rule in ReplayRule.allCases { #expect(HouseRuleGuide.entry(for: rule).rules.contains(rule)) }
    #expect(HouseRuleGuide.entry(id: "unknown") == nil)
    let matching = HouseRuleGuide.entry(for: .dealerMatch)
    #expect(matching.paragraphs.contains(RulesText.sections[4].paragraphs[1]))
    #expect(HouseRuleGuide.entry(for: .highLowPlayed).id != HouseRuleGuide.entry(for: .trumpWins).id)
}

@Test func ruleSearchHandlesAliasesAndSeparatesHighFromTrickWinning() {
    #expect(HouseRuleGuide.search("").map(\.id) == HouseRuleGuide.entries.map(\.id))
    #expect(HouseRuleGuide.search("  ").count == HouseRuleGuide.entries.count)
    #expect(HouseRuleGuide.search("9 & out").map(\.id) == HouseRuleGuide.search("nine-and-out").map(\.id))
    #expect(HouseRuleGuide.search("NÍNE AND OUT").map(\.id) == HouseRuleGuide.search("9 & out").map(\.id))
    #expect(HouseRuleGuide.search("highest trump played").first?.id == HouseRuleGuide.entry(for: .highLowPlayed).id)
    #expect(HouseRuleGuide.search("dealer match").first?.id == HouseRuleGuide.entry(for: .dealerMatch).id)
    #expect(HouseRuleGuide.search("follow suit").contains { $0.rules.contains(.followSuit) })
    #expect(HouseRuleGuide.search("unfindable giraffe").isEmpty)
    #expect(!HouseRuleGuide.search("King").isEmpty)
}

@Test func ruleExamplesUseEngineScoringAndSettlement() throws {
    let high = try HouseRuleGuide.playedHighExample()
    #expect(high.highTeam == 0 && high.lowTeam == 1)
    #expect(high.jackTeam == nil && high.fiveTeam == nil)
    #expect(high.points.reduce(0, +) == 3)
    #expect(try HouseRuleGuide.tiedGameExample().gameTeam == 1)
    let set = try HouseRuleGuide.setBidExample()
    #expect(set.scores == [5, 10] && set.winner == nil)
    let ordinary = try HouseRuleGuide.nineExample(special: false)
    let special = try HouseRuleGuide.nineExample(special: true)
    #expect(ordinary.scores == [-9, 1] && ordinary.winner == nil)
    #expect(special.scores == [0, 0] && special.winner == 1)
    #expect(throws: RuleError.forbiddenNineAndOut) { try HouseRuleGuide.nineExample(special: true, startingScore: -1) }
}

@Test func ruleGuidePlayAuctionAndTargetExamplesMatchTheEngine() throws {
    let heart = Card(.hearts, .ace), club = Card(.clubs, .two)
    let trick = [Play(seat: 0, card: heart), Play(seat: 1, card: club),
                 Play(seat: 2, card: Card(.hearts, .king)), Play(seat: 3, card: Card(.diamonds, .ace))]
    #expect(try trickWinner(trick, trump: .clubs) == 1)
    #expect(legalCards(in: [heart, club], led: .hearts) == [heart])
    #expect(legalCards(in: [heart, club], led: nil, openingTrump: .clubs) == [club])
    var ordinary = try Auction(dealer: 3)
    try ordinary.act(seat: 0, bid: 4)
    try ordinary.act(seat: 1, bid: nil)
    try ordinary.act(seat: 2, bid: nil)
    try ordinary.act(seat: 3, bid: 4)
    #expect(ordinary.winner == 3)
    var special = try Auction(dealer: 3)
    try special.act(seat: 0, bid: 9, nineAndOut: true)
    try special.act(seat: 1, bid: nil)
    try special.act(seat: 2, bid: nil)
    #expect(throws: RuleError.invalidBid) { try special.act(seat: 3, bid: 9) }
    #expect(throws: RuleError.invalidBid) { try special.act(seat: 3, bid: 9, nineAndOut: true) }
    #expect(try settle(scores: [0, 0], points: [9, 0], bidder: 0, bid: .nineAndOut).winner == 0)
    #expect(try settle(scores: [24, 24], points: [2, 7], bidder: 0, bid: .points(2)).winner == 0)
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var match = try Match(deck: deck, dealer: 3)
    try match.bid(seat: 0, amount: 2)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    let held = match.hand.hands
    try match.chooseTrump(seat: 0, suit: .clubs)
    for seat in 0..<4 {
        #expect(match.hand.hands[seat].count == 6)
        #expect(match.hand.discardCounts[seat] == held[seat].filter { $0.suit != .clubs }.count)
        #expect(held[seat].filter { $0.suit == .clubs }.allSatisfy { match.hand.hands[seat].contains($0) })
    }
}
