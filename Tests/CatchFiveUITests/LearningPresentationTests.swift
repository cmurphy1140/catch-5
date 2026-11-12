import CatchFive
@testable import CatchFiveUI
import Testing

private func playbackReplay(nineAndOut: Bool = false, bid: Int = 2) throws -> HandReplay {
    var match = try Match(deck: PracticeDeal.trumpRich.deck(), dealer: 3)
    if nineAndOut { try match.bidNineAndOut(seat: 0) } else { try match.bid(seat: 0, amount: bid) }
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .hearts)
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    return try HandReplay(match: match)
}

@Test func replayPlaybackReachesEveryHistoricalStepWithoutWrappingOrSkipping() throws {
    let replay = try playbackReplay()
    var playback = ReplayPlayback(replay: replay)
    #expect(playback.current == replay.steps[0] && !playback.canGoBack)
    playback.previous()
    #expect(playback.index == 0)
    var visited = [playback.current.id]
    while playback.canGoForward { playback.next(); visited.append(playback.current.id) }
    #expect(visited == replay.steps.map(\.id))
    playback.next()
    #expect(playback.current == replay.steps.last && !playback.canGoForward)
    while playback.canGoBack { playback.previous() }
    #expect(playback.index == 0 && playback.canGoForward)
}

@Test func replayPlaybackDirectSelectionUsesStableEventIDAndRejectsInvalidValues() throws {
    let replay = try playbackReplay()
    var playback = ReplayPlayback(replay: replay)
    for step in replay.steps.reversed() {
        playback.select(id: step.id)
        #expect(playback.current == step)
    }
    playback.select(id: -1)
    playback.select(id: replay.steps.count + 1)
    #expect(playback.index == 0)
}

@Test func replayCopyDistinguishesNormalNineFromNineAndOutAndKeepsActualScoreTotals() throws {
    let normal = try playbackReplay(bid: 9)
    let special = try playbackReplay(nineAndOut: true)
    let labels = LearningSeatLabels(names: ["Same", "Same", "Partner", "Right"], mode: .solo)
    #expect(ReplayWording.contract(normal) == "Bid 9 · Hearts trump")
    #expect(ReplayWording.contract(special) == "9 and out · Hearts trump")
    let normalResult = try #require(normal.finishedMatch.hand.result)
    let specialResult = try #require(special.finishedMatch.hand.result)
    #expect(!ReplayWording.settlement(normal, result: normalResult, labels: labels).contains("numeric scores stay"))
    #expect(ReplayWording.settlement(special, result: specialResult, labels: labels).contains("numeric scores stay as they were"))
    #expect(special.before == special.after)
    #expect(ReplayWording.scoreLine(team: 0, before: special.before, after: special.after, labels: labels) == "Us: 0 → 0")
}

@Test func replayLabelsDisambiguateDuplicateNamesAndNameSuitsBeyondTheirColor() throws {
    let names = ["Same", "Same", "Very long partner name", "Right"]
    let sharedPhone = LearningSeatLabels(names: names, mode: .passAndPlay)
    #expect(sharedPhone.name(0) != sharedPhone.name(1))
    #expect(sharedPhone.team(0).contains("seats 1 & 3") && sharedPhone.team(1).contains("seats 2 & 4"))
    #expect(!sharedPhone.team(0).contains("Us"))
    for suit in Suit.allCases {
        let words = ReplayWording.title(.trump(seat: 1, suit: suit), labels: sharedPhone)
        #expect(words.contains(suit.rawValue) && words.contains("seat 2"))
    }
}
