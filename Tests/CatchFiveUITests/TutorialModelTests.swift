import CatchFive
import CatchFiveUI
import Foundation
import Testing

@MainActor @Test func completingAllLessonsPersistsAcrossLaunch() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var settings = Settings()
    let model = TutorialModel(completed: settings.completedLessons) { settings.completedLessons = $0 }
    #expect(model.completed.isEmpty && model.lesson == 0)
    for lesson in 0..<TutorialModel.lessonCount { model.complete(lesson) }
    #expect(model.completed == Set(0..<TutorialModel.lessonCount))
    try SettingsStore.write(settings, to: url)
    let reloaded = TutorialModel(completed: try SettingsStore.read(from: url).completedLessons) { _ in }
    #expect(reloaded.completed.count == TutorialModel.lessonCount)
    #expect(reloaded.lesson == 0)
}

@MainActor @Test func biddingExerciseLegalSetIsFourThroughNinePassAndNineAndOut() {
    let legal = TutorialFixtures.legalBids
    #expect(legal == Set([4, 5, 6, 7, 8, 9].map(TutorialBid.points) + [.pass, .nineAndOut]))
    #expect(!legal.contains(.points(2)) && !legal.contains(.points(3)))
    let model = TutorialModel(completed: []) { _ in }
    model.chooseBid(.points(3))
    #expect(model.bidFeedback.contains("raise") && !model.completed.contains(1))
    model.chooseBid(.points(4))
    #expect(model.completed.contains(1))
}

@Test func tricksExerciseLegalMovesMatchEngine() {
    let legal = legalCards(in: TutorialFixtures.trickHand, led: TutorialFixtures.trickLead.suit)
    #expect(Set(legal) == Set(TutorialFixtures.trickLegalAnswers))
    #expect(Set(legal) == Set([Card(.diamonds, .nine), Card(.diamonds, .two)]))
}

@Test func tricksExerciseWinnerMatchesEngine() throws {
    let winner = try trickWinner(TutorialFixtures.fullTrick, trump: .spades)
    #expect(winner == 3)
    #expect(winner == TutorialFixtures.trickWinnerAnswer)
}

@Test func scoringExerciseMatchesScoreHand() throws {
    let score = try scoreHand(captured: [TutorialFixtures.usCaptured, TutorialFixtures.themCaptured], trump: .spades, bidder: 1)
    #expect(score.points == [2, 7])
    #expect(score.highTeam == 0 && score.lowTeam == 0 && score.jackTeam == 1 && score.fiveTeam == 1 && score.gameTeam == 1)
    #expect(TutorialFixtures.scoringAnswers == [.high: 0, .low: 0, .jack: 1, .five: 1, .game: 1])
    let settled = try settle(scores: [10, 5], points: score.points, bidder: 1, bid: .points(4))
    #expect(settled.scores == [12, 12] && settled.winner == nil)
}
