import Testing
@testable import CatchFive

private func replayDeck(_ number: Int = 1) -> [Card] {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let rotation = (number * 7) % deck.count
    return Array(deck[rotation...]) + Array(deck[..<rotation])
}

private func finishReplayHand(_ match: inout Match, bid: Int = 2, nineAndOut: Bool = false, trump: Suit? = nil) throws {
    let bidder = (match.hand.auction.dealer + 1) % 4
    if nineAndOut { try match.bidNineAndOut(seat: bidder) }
    else { try match.bid(seat: bidder, amount: bid) }
    for offset in 1...3 { try match.bid(seat: (bidder + offset) % 4, amount: nil) }
    try match.chooseTrump(seat: bidder, suit: trump ?? Suit.allCases[match.handNumber % 4])
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
}

@Test func replayRejectsUnfinishedAndUnknownHands() throws {
    let match = try Match(deck: replayDeck(), dealer: 3)
    #expect(throws: HandReplayError.handNotFinished) { try HandReplay(match: match) }
    #expect(throws: HandReplayError.handNotFinished) { try HandReplay(match: match, handNumber: 1) }
    for number in [-1, 0, 2] {
        #expect(throws: HandReplayError.handNotFound) { try HandReplay(match: match, handNumber: number) }
    }
}

@Test func replayKeepsEveryAuctionCallAndTheDealerMatch() throws {
    var match = try Match(deck: replayDeck(), dealer: 3)
    let dealt = match.hand.hands
    try match.bid(seat: 0, amount: 2)
    try match.bid(seat: 1, amount: nil)
    try match.bid(seat: 2, amount: 4)
    try match.bid(seat: 3, amount: 4)
    try match.chooseTrump(seat: 3, suit: .hearts)
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    let replay = try HandReplay(match: match)
    let calls = replay.steps.compactMap { step -> AuctionCall? in
        guard case let .bid(seat, bid) = step.event else { return nil }
        return AuctionCall(seat: seat, bid: bid)
    }
    #expect(calls == match.hand.auction.calls)
    #expect(replay.steps.first?.event == .deal(dealer: 3))
    #expect(replay.steps.first?.hands == dealt)
    let matching = try #require(replay.steps.first { $0.event == .bid(seat: 3, bid: .points(4)) })
    #expect(matching.rules.contains(.dealerMatch))
    #expect(replay.bidder == 3 && replay.bid == 4 && replay.trump == .hearts)
    #expect(replay.steps.map(\.id) == Array(replay.steps.indices))
}

@Test func replayShowsAutomaticDiscardsAndRefillsInTheRealOrder() throws {
    var match = try Match(deck: replayDeck(), dealer: 1)
    let dealt = match.hand.hands
    var stock = match.hand.stock
    try finishReplayHand(&match, trump: .hearts)
    let replay = try HandReplay(match: match)
    let trump = try #require(replay.steps.first { if case .trump = $0.event { true } else { false } })
    #expect(trump.hands == dealt)
    let discards = replay.steps.filter { if case .discard = $0.event { true } else { false } }
    #expect(discards.count == 4)
    var expectedHands = dealt
    for (step, seat) in zip(discards, [2, 3, 0, 1]) {
        guard case let .discard(actor, thrown, drawn) = step.event else { Issue.record("Expected discard"); continue }
        let kept = dealt[seat].filter { $0.suit == .hearts }
        let expectedDraw = Array(stock.prefix(6 - kept.count))
        stock.removeFirst(expectedDraw.count)
        #expect(actor == seat)
        #expect(thrown == dealt[seat].filter { $0.suit != .hearts })
        #expect(drawn == expectedDraw)
        #expect(thrown.count == match.hand.discardCounts[seat])
        expectedHands[seat] = kept + expectedDraw
        #expect(step.hands == expectedHands)
        #expect(step.rules == [.discardAndRefill])
    }
    #expect(discards.last?.hands.flatMap { $0 }.count == 24)
}

@Test func replaySeparatesPlaysTrickAwardsAndScoreSettlement() throws {
    var match = try Match(deck: replayDeck(), dealer: 3)
    try finishReplayHand(&match)
    let replay = try HandReplay(match: match)
    let plays = replay.steps.filter { if case .play = $0.event { true } else { false } }
    let tricks = replay.steps.filter { if case .trick = $0.event { true } else { false } }
    let scores = replay.steps.filter { if case .score = $0.event { true } else { false } }
    #expect(plays.count == 24 && tricks.count == 6 && scores.count == 1)
    #expect(plays.compactMap { if case let .play(play) = $0.event { play } else { nil } } == match.hand.completedTricks.flatMap(\.plays))
    for (index, step) in plays.enumerated() {
        guard case let .play(play) = step.event else { continue }
        #expect(!step.hands[play.seat].contains(play.card))
        #expect(step.hands.flatMap { $0 }.count == 23 - index)
        #expect(step.currentTrick.count == index % 4 + 1)
        #expect(step.currentTrick.last == play)
        #expect(step.scores == [0, 0])
    }
    for (index, step) in tricks.enumerated() {
        guard case let .trick(number, cards, winner) = step.event else { continue }
        #expect(number == index + 1)
        #expect(cards == match.hand.completedTricks[index].plays)
        #expect(winner == match.hand.completedTricks[index].winner)
        #expect(winner == (try trickWinner(cards, trump: replay.trump)))
        #expect(step.scores == [0, 0])
        let position = try #require(replay.steps.firstIndex { $0.id == step.id })
        #expect(replay.steps[position - 1].currentTrick == cards)
    }
    let final = try #require(scores.first)
    guard case let .score(before, after, result, winner, nineAndOut) = final.event else { return }
    #expect(before == [0, 0] && after == match.scores && result == match.hand.result)
    #expect(winner == match.winner && !nineAndOut)
    #expect(final.scores == match.scores && final.hands == [[], [], [], []])
    #expect(final == replay.steps.last)
    #expect(final.rules.contains(.highLowPlayed) && final.rules.contains(.capturedScoring))
    #expect(final.rules.contains(.ordinarySettlement))
}

@Test func replayKeepsEarlierHandsSeparateFromTheLiveNextHand() throws {
    var match = try Match(deck: replayDeck(), dealer: 3)
    try finishReplayHand(&match)
    let completed = match
    let original = try HandReplay(match: completed)
    try match.startNextHand(deck: replayDeck(2))
    try match.bid(seat: 1, amount: 9)
    let earlier = try HandReplay(match: match, handNumber: 1)
    #expect(earlier.steps == original.steps)
    #expect(earlier.deal == original.deal)
    #expect(earlier.number == 1 && earlier.finishedMatch.handNumber == 1)
    #expect(earlier.finishedMatch.hand.phase == .finished)
    #expect(try MatchSave.encode(earlier.finishedMatch) == MatchSave.encode(completed))
    #expect(throws: HandReplayError.handNotFinished) { try HandReplay(match: match) }
}

@Test func replayUsesOriginalScoresAndAStableHandStartAcrossHands() throws {
    var match = try Match(deck: replayDeck(), dealer: 3)
    #expect(match.handStartActionCount == 0)
    try finishReplayHand(&match)
    #expect(match.handStartActionCount == 0)
    let oldCount = match.actionCount
    let before = match.scores
    try match.startNextHand(deck: replayDeck(2))
    let dealt = match.hand.hands
    #expect(match.handStartActionCount == oldCount + 1)
    try finishReplayHand(&match)
    let replay = try HandReplay(match: match)
    #expect(replay.dealStartActionCount == oldCount + 1)
    #expect(match.handStartActionCount == oldCount + 1)
    #expect(replay.before == before && replay.after == match.scores)
    #expect(replay.steps.first?.hands == dealt)
    #expect(replay.steps.dropLast().allSatisfy { $0.scores == before })
    let practice = try replay.practiceMatch()
    #expect(practice.handNumber == 1 && practice.history.isEmpty && practice.scores == [0, 0] && practice.winner == nil)
    #expect(practice.hand.phase == .bidding && practice.hand.hands == dealt)
    #expect(practice.hand.auction.dealer == 0 && practice.actionCount == 0)
    #expect(practice.hand.stock == (try Match(deck: replayDeck(2), dealer: 0)).hand.stock)
}

@Test func replaySurvivesSaveRoundTripDeterministically() throws {
    var match = try Match(deck: replayDeck(), dealer: 2)
    try finishReplayHand(&match)
    let original = try HandReplay(match: match)
    let restored = try HandReplay(match: MatchSave.decode(MatchSave.encode(match)))
    #expect(original.steps == restored.steps)
    #expect(original.deal == restored.deal)
    #expect(original.before == restored.before && original.after == restored.after)
    #expect(try MatchSave.encode(original.finishedMatch) == MatchSave.encode(restored.finishedMatch))
    #expect(try MatchSave.encode(original.practiceMatch()) == MatchSave.encode(restored.practiceMatch()))
}

@Test func replayDistinguishesOrdinaryNineFromNineAndOutWithoutInventingScoreChanges() throws {
    for special in [false, true] {
        var match = try Match(deck: replayDeck(), dealer: 3)
        try finishReplayHand(&match)
        let before = match.scores
        try match.startNextHand(deck: replayDeck(2))
        try finishReplayHand(&match, bid: 9, nineAndOut: special)
        let replay = try HandReplay(match: match)
        #expect(replay.bid == 9 && replay.isNineAndOut == special)
        #expect(replay.before == before && replay.after == match.scores)
        let bid = try #require(replay.steps.first { if case .bid = $0.event { true } else { false } })
        #expect(bid.event == .bid(seat: 1, bid: special ? .nineAndOut : .points(9)))
        let score = try #require(replay.steps.last)
        guard case let .score(old, new, result, winner, nineAndOut) = score.event else { Issue.record("Missing score"); continue }
        #expect(old == before && new == match.scores && result == match.hand.result && nineAndOut == special)
        if special {
            #expect(new == before)
            #expect(winner == match.winner && winner != nil)
            #expect(score.rules.contains(.nineAndOut) && !score.rules.contains(.ordinarySettlement))
        } else {
            #expect(new != before && winner == nil)
            #expect(score.rules.contains(.ordinarySettlement) && !score.rules.contains(.nineAndOut))
        }
    }
}

@Test func replayReferencesTheRuleThatAppliesToEachPlayAndTrick() throws {
    var match = try Match(deck: replayDeck(), dealer: 3)
    try finishReplayHand(&match)
    let replay = try HandReplay(match: match)
    let opening = try #require(replay.steps.first { if case .play = $0.event { true } else { false } })
    #expect(opening.rules.contains(.openingTrump))
    var previousHands = replay.steps.first!.hands
    for step in replay.steps {
        if case let .play(play) = step.event, let led = step.currentTrick.first, led != play {
            let hadSuit = previousHands[play.seat].contains { $0.suit == led.card.suit }
            #expect(step.rules.contains(.followSuit) == hadSuit)
        }
        if case let .trick(_, plays, _) = step.event {
            let hasTrump = plays.contains { $0.card.suit == replay.trump }
            #expect(step.rules.contains(.trumpWins) == hasTrump)
            #expect(step.rules.contains(.ledSuitWins) == !hasTrump)
        }
        previousHands = step.hands
    }
}

@Test func replayScoringReferencesCapturedCardsAndExplainsGameTies() throws {
    var missing: Match?, relative: Match?, tied: Match?
    for seed in 1...300 where missing == nil || relative == nil || tied == nil {
        var random = RepeatableRandom(state: UInt64(seed))
        var match = try Match(deck: replayDeck().shuffled(using: &random), dealer: seed % 4)
        try finishReplayHand(&match, trump: .hearts)
        let result = try #require(match.hand.result)
        let played = match.hand.captured.flatMap { $0 }.filter { $0.suit == .hearts }
        if result.jackTeam == nil || result.fiveTeam == nil { missing = match }
        if played.map(\.rank.rawValue).max() != Rank.ace.rawValue { relative = match }
        if result.gameValues[0] == result.gameValues[1] { tied = match }
    }
    for match in [try #require(missing), try #require(relative), try #require(tied)] {
        let replay = try HandReplay(match: match)
        let step = try #require(replay.steps.last)
        guard case let .score(_, _, result, _, _) = step.event else { Issue.record("Missing score"); continue }
        #expect(result == match.hand.result)
        #expect(step.rules.contains(.highLowPlayed) && step.rules.contains(.capturedScoring))
        #expect(step.rules.contains(.gameTie) == (result.gameValues[0] == result.gameValues[1]))
        if result.gameValues[0] == result.gameValues[1] { #expect(result.gameTeam == replay.bidder % 2) }
    }
}
