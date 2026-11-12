import CatchFive
@testable import CatchFiveUI
import Testing

private func trickTeachingMatch() throws -> Match {
    var match = try Match(deck: PracticeDeal.trumpRich.deck(), dealer: 3)
    try match.bid(seat: 0, amount: 2)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .hearts)
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    return match
}

@Test func trickExplanationNamesTheOnlyTrumpEvenWhenAnAceWasLed() throws {
    let plays = [
        Play(seat: 2, card: Card(.hearts, .ace)),
        Play(seat: 3, card: Card(.hearts, .king)),
        Play(seat: 0, card: Card(.spades, .four)),
        Play(seat: 1, card: Card(.diamonds, .ace))
    ]
    let answer = try #require(ReplayTrickPresentation(plays: plays, winner: 0, trump: .spades))
    #expect(answer.winningPlay == plays[2] && answer.led == .hearts && answer.rule == .trumpWins)
    #expect(answer.explanation == "Hearts led. The four of spades was the only trump, so it took the trick.")
}

@Test func trickExplanationComparesTheWinningTrumpWithTheHighestOtherTrump() throws {
    let plays = [
        Play(seat: 1, card: Card(.hearts, .ace)),
        Play(seat: 2, card: Card(.spades, .seven)),
        Play(seat: 3, card: Card(.spades, .king)),
        Play(seat: 0, card: Card(.spades, .ten))
    ]
    let answer = try #require(ReplayTrickPresentation(plays: plays, winner: 3, trump: .spades))
    #expect(answer.winningPlay == plays[2] && answer.rule == .trumpWins)
    #expect(answer.explanation.contains("king of spades was the highest trump, beating the ten of spades"))
    #expect(!answer.explanation.contains("seven of spades"))
}

@Test func trickExplanationNamesTheLedSuitComparisonAndIgnoresOffSuitAces() throws {
    let plays = [
        Play(seat: 0, card: Card(.hearts, .ten)),
        Play(seat: 1, card: Card(.clubs, .ace)),
        Play(seat: 2, card: Card(.hearts, .six)),
        Play(seat: 3, card: Card(.diamonds, .ace))
    ]
    let answer = try #require(ReplayTrickPresentation(plays: plays, winner: 0, trump: .spades))
    #expect(answer.winningPlay == plays[0] && answer.rule == .ledSuitWins)
    #expect(answer.explanation.contains("no trump was played"))
    #expect(answer.explanation.contains("ten of hearts was the highest card of the led suit, beating the six of hearts"))
}

@Test func trickExplanationCoversAWinningLeadThatNobodyCouldFollow() throws {
    let plays = [
        Play(seat: 3, card: Card(.hearts, .two)),
        Play(seat: 0, card: Card(.clubs, .ace)),
        Play(seat: 1, card: Card(.clubs, .king)),
        Play(seat: 2, card: Card(.diamonds, .ace))
    ]
    let answer = try #require(ReplayTrickPresentation(plays: plays, winner: 3, trump: .spades))
    #expect(answer.rule == .ledSuitWins)
    #expect(answer.explanation.contains("two of hearts was the only card of the led suit"))
}

@Test func trickExplanationRejectsPartialInvalidOrContradictoryHistory() {
    let plays = [
        Play(seat: 0, card: Card(.hearts, .ace)),
        Play(seat: 1, card: Card(.hearts, .king)),
        Play(seat: 2, card: Card(.spades, .four)),
        Play(seat: 3, card: Card(.diamonds, .ace))
    ]
    #expect(ReplayTrickPresentation(plays: Array(plays.prefix(3)), winner: 2, trump: .spades) == nil)
    #expect(ReplayTrickPresentation(plays: plays, winner: 0, trump: .spades) == nil)
    var duplicateSeat = plays
    duplicateSeat[3] = Play(seat: 2, card: Card(.diamonds, .ace))
    #expect(ReplayTrickPresentation(plays: duplicateSeat, winner: 2, trump: .spades) == nil)
    var duplicateCard = plays
    duplicateCard[3] = Play(seat: 3, card: Card(.spades, .four))
    #expect(ReplayTrickPresentation(plays: duplicateCard, winner: 2, trump: .spades) == nil)
}

@Test func eachTrickDeepLinkStartsWithItsRecordedLead() throws {
    let replay = try HandReplay(match: trickTeachingMatch())
    #expect(replay.finishedMatch.hand.completedTricks.count == 6)
    for (index, trick) in replay.finishedMatch.hand.completedTricks.enumerated() {
        let id = try #require(ReplayTrickPresentation.firstPlayStepID(number: index + 1, in: replay))
        let step = try #require(replay.steps.first { $0.id == id })
        #expect(step.currentTrick == [trick.plays[0]])
        if case let .play(play) = step.event { #expect(play == trick.plays[0]) }
        else { Issue.record("A trick deep link must select its first card, never its award or the deal.") }
    }
    #expect(ReplayTrickPresentation.firstPlayStepID(number: 0, in: replay) == nil)
    #expect(ReplayTrickPresentation.firstPlayStepID(number: 7, in: replay) == nil)
}

@Test func theFourthCardAndItsRecordedAwardShowTheSameExplanation() throws {
    let replay = try HandReplay(match: trickTeachingMatch())
    var explained = 0
    for (index, step) in replay.steps.enumerated() {
        guard case .play = step.event else { continue }
        let answer = ReplayTrickPresentation.forStep(step, in: replay)
        if step.currentTrick.count < 4 {
            #expect(answer == nil)
        } else {
            let completed = try #require(answer)
            let award = replay.steps[index + 1]
            #expect(completed == ReplayTrickPresentation.forStep(award, in: replay))
            #expect(completed.winningPlay.seat == (try trickWinner(step.currentTrick, trump: replay.trump)))
            explained += 1
        }
    }
    #expect(explained == 6)
}

@MainActor @Test func trickCursorSurvivesRulesAndPracticeWithoutChangingTheRealMatch() throws {
    let match = try trickTeachingMatch()
    let replay = try HandReplay(match: match)
    let real = GameModel(match: match)
    let before = try MatchSave.encode(real.match)
    let first = try #require(ReplayTrickPresentation.firstPlayStepID(number: 3, in: replay))
    let flow = LearningFlowModel(real: real, start: .replay(replay, names: ["Same", "Same", "Partner", "Right"],
                                                          mode: .passAndPlay, initialStepID: first, bottomSeat: 3))
    #expect(flow.replayStepID == first && flow.replayBottomSeat == 3)
    #expect((0..<4).map { ReplayTrickPresentation.seat(at: $0, bottomSeat: flow.replayBottomSeat) } == [3, 0, 1, 2])
    let fourth = try #require(replay.steps.first { step in
        if case .play = step.event { return step.id >= first && step.currentTrick.count == 4 }
        return false
    })
    flow.selectReplayStep(id: fourth.id)
    flow.showRule(.trumpWins)
    #expect(flow.path.last == .rule("trick"))
    flow.back()
    #expect(flow.path.isEmpty && flow.replayStepID == fourth.id)
    flow.beginPractice()
    flow.startPractice(PracticeConfiguration())
    #expect(flow.practiceModel?.isPractice == true)
    #expect(!flow.leavePractice() && flow.replayStepID == fourth.id)
    flow.selectReplayStep(id: -1)
    flow.selectReplayStep(id: replay.steps.count + 1)
    #expect(flow.replayStepID == fourth.id)
    var restored = ReplayPlayback(replay: replay)
    restored.select(id: try #require(flow.replayStepID))
    #expect(restored.current.currentTrick == fourth.currentTrick && restored.current.currentTrick.count == 4)
    #expect(try MatchSave.encode(real.match) == before)
}

@Test func reviewNamesKeepRepeatedNamesDistinctWithoutAddingNoiseToUniqueNames() {
    let names = ["Same", "Same", "Partner", "Right"]
    #expect(LearningSeatLabels.reviewName(0, in: names) == "Same · seat 1")
    #expect(LearningSeatLabels.reviewName(1, in: names) == "Same · seat 2")
    #expect(LearningSeatLabels.reviewName(2, in: names) == "Partner")
}
