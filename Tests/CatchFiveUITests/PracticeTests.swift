import CatchFive
@testable import CatchFiveUI
import Foundation
import Testing

private func practiceTestDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@MainActor private func drivePracticeToMatchEnd(_ model: GameModel) throws {
    for _ in 0..<100 where model.match.winner == nil {
        if model.isHumanTurn {
            switch model.match.hand.phase {
            case .bidding: model.send(.nineAndOut)
            case .choosingTrump: model.send(.chooseTrump(.hearts))
            case .playing: model.send(.play(try #require(model.match.hand.legalMoves(seat: 0).first)))
            case .finished: model.nextHand()
            }
        } else { model.stepComputer() }
    }
    #expect(model.match.winner != nil)
}

@Test func practiceSamplesAreDeterministicValidDealsWithThePromisedHumanCards() throws {
    for deal in PracticeDeal.allCases {
        let deck = deal.deck()
        #expect(deck.count == 52 && Set(deck).count == 52)
        let match = try Match(deck: deck, dealer: 3)
        #expect(match.hand.nextSeat == 0 && match.scores == [0, 0])
        if deal != .fresh { #expect(deal.deck() == deck) }
        if deal == .trumpRich { #expect(match.hand.hands[0].filter { $0.suit == .hearts }.count == 6) }
        if deal == .mixed { #expect(Set(match.hand.hands[0].map(\.suit)).count == 4) }
    }
}

@MainActor @Test func wholePracticeMatchAndRestartLeaveTheRealGameAndFilesUntouched() throws {
    let directory = try practiceTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let cards = PracticeDeal.mixed.deck()
    let game = directory.appendingPathComponent("game.json")
    let settingsURL = directory.appendingPathComponent("settings.json")
    let history = directory.appendingPathComponent("history.json")
    let archive = directory.appendingPathComponent("hands")
    let settings = Settings(playerName: "Connor")
    let real = GameModel(match: try Match(deck: cards, dealer: 3), saveURL: game, settings: settings,
                         settingsURL: settingsURL, historyURL: history, archiveDirectory: archive)
    real.persist()
    try SettingsStore.write(settings, to: settingsURL)
    try MatchHistoryStore.write([], to: history)
    let paths = [game, settingsURL, history, directory.appendingPathComponent("game-mode.json")]
    let bytes = try paths.map { try Data(contentsOf: $0) }
    let snapshot = try MatchSave.encode(real.match)
    let configuration = PracticeConfiguration(left: .easy, partner: .standard, right: .easy, deal: .trumpRich)
    let practice = try real.makePractice(configuration: configuration)
    #expect(practice.isPractice && practice.mode == .solo)
    #expect(practice.effectiveDifficulty(forSeat: 1) == .easy && practice.effectiveDifficulty(forSeat: 2) == .standard)
    #expect(practice.effectiveDifficulty(forSeat: 3) == .easy)
    try drivePracticeToMatchEnd(practice)
    #expect(practice.records.isEmpty && practice.savedHands().entries.isEmpty && practice.archiveStatistics.hands == 0)
    practice.newGame(mode: .passAndPlay)
    #expect(practice.isPractice && practice.mode == .solo && practice.match.hand.auction.dealer == 3)
    #expect(practice.match.hand.hands[0].filter { $0.suit == .hearts }.count == 6)
    practice.settings.playerName = "Practice only"
    practice.persist()
    practice.retrySave()
    practice.retryArchive()
    #expect(try paths.map { try Data(contentsOf: $0) } == bytes)
    #expect(try MatchSave.encode(real.match) == snapshot && real.settings == settings && real.records.isEmpty)
    #expect(real.savedHands().entries.isEmpty)
}

@MainActor @Test func practiceInitializerCannotUseSuppliedRealPersistenceOrArchiveURLs() throws {
    let directory = try practiceTestDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let urls = ["game.json", "settings.json", "history.json"].map { directory.appendingPathComponent($0) }
    for url in urls { try Data("keep".utf8).write(to: url) }
    let archive = directory.appendingPathComponent("must-not-exist")
    let practice = GameModel(match: try Match(deck: PracticeDeal.trumpRich.deck(), dealer: 3), mode: .passAndPlay,
                             saveURL: urls[0], settings: Settings(playerName: "Connor"), settingsURL: urls[1],
                             historyURL: urls[2], practice: PracticeConfiguration(), archiveDirectory: archive)
    #expect(practice.mode == .solo)
    practice.settings.haptics = false
    try drivePracticeToMatchEnd(practice)
    practice.retrySave()
    #expect(try urls.map { try Data(contentsOf: $0) } == Array(repeating: Data("keep".utf8), count: 3))
    #expect(!FileManager.default.fileExists(atPath: archive.path))
    #expect(practice.records.isEmpty && practice.archiveStatistics.hands == 0)
}

@MainActor @Test func practiceRetryStartsTheExactArchivedDealWithoutItsOriginalScoresOrHistory() throws {
    var match = try Match(deck: PracticeDeal.mixed.deck(), dealer: 1)
    try match.bid(seat: 2, amount: 2)
    for seat in [3, 0, 1] { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 2, suit: .spades)
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    let replay = try HandReplay(match: match)
    let real = GameModel(match: match, settings: Settings(playerName: "Connor"))
    let practice = try real.makePractice(configuration: PracticeConfiguration(), replay: replay)
    #expect(practice.match.hand.auction.dealer == replay.dealer)
    #expect(practice.match.hand.hands == replay.steps[0].hands)
    #expect(practice.match.scores == [0, 0] && practice.match.history.isEmpty && practice.match.actionCount == 0)
    #expect(try MatchSave.encode(real.match) == MatchSave.encode(match))
}

@MainActor @Test func practiceDifficultyControlsDecisionsAndHistoricalLabelsForEachSeat() throws {
    let configuration = PracticeConfiguration(left: .easy, partner: .standard, right: .easy)
    let model = GameModel(match: try Match(deck: PracticeDeal.mixed.deck(), dealer: 0), practice: configuration)
    let view = try PlayerView(match: model.match, seat: 1)
    let expected = try #require(ComputerPlayer.decide(view, difficulty: .easy))
    model.stepComputer()
    switch expected {
    case let .bid(amount): #expect(model.match.hand.auction.calls.last?.bid == amount.map(Bid.points))
    case .nineAndOut: #expect(model.match.hand.auction.calls.last?.bid == .nineAndOut)
    default: Issue.record("Expected bidding decision")
    }
    let advice = try #require(ComputerPlayer.advise(PlayerView(seat: 1, cards: [Card(.hearts, .ace)], phase: .playing,
        nextSeat: 1, dealer: 0, highestBid: 2, bidder: 1, trump: .hearts, trick: [])))
    let review = PlayReview(play: Play(seat: 1, card: Card(.hearts, .king)), advice: advice)
    #expect(model.describe(review).contains("(easy)"))
    let standard = PlayReview(play: Play(seat: 2, card: Card(.hearts, .king)), advice: review.advice)
    #expect(!model.describe(standard).contains("(easy)"))
    #expect(configuration.difficulty(forSeat: -1) == .standard && configuration.difficulty(forSeat: 0) == .standard)
}

@MainActor @Test func practiceBoldNotesUseTheActingSeatsDifficultyRatherThanTheGlobalSetting() throws {
    struct Seeded: RandomNumberGenerator {
        var state: UInt64
        mutating func next() -> UInt64 { state = state &* 6364136223846793005 &+ 1442695040888963407; return state }
    }
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var behind: Match?
    for seed in 1...200 where behind == nil {
        var random = Seeded(state: UInt64(seed))
        var match = try Match(deck: deck.shuffled(using: &random), dealer: 0)
        while match.winner == nil {
            if match.hand.phase == .finished {
                try match.startNextHand(deck: deck.shuffled(using: &random))
                if match.scores[0] - match.scores[1] >= 10, match.hand.nextSeat == 1 { behind = match; break }
            } else {
                let seat = try #require(match.hand.nextSeat)
                try match.apply(try #require(ComputerPlayer.decide(PlayerView(match: match, seat: seat))), seat: seat)
            }
        }
    }
    let match = try #require(behind)
    let easy = GameModel(match: match, settings: Settings(difficulty: .standard), practice: PracticeConfiguration(left: .easy))
    let standard = GameModel(match: match, settings: Settings(difficulty: .easy), practice: PracticeConfiguration(left: .standard))
    #expect(easy.boldNote(for: 1) == nil && standard.boldNote(for: 1) != nil)
}

@Test func everyPracticeDealSaysWhatItGivesInItsOwnWords() {
    let details = PracticeDeal.allCases.map(\.detail)
    #expect(details.allSatisfy { !$0.isEmpty })
    #expect(Set(details).count == PracticeDeal.allCases.count)
}

@Test func aPinkedSwatchHasAValleyAndAPeakForEveryToothAndStaysInsideItsSquare() {
    let rect = CGRect(x: 10, y: 20, width: 90, height: 90)
    let points = PinkedSquare.points(in: rect, teeth: 9)
    #expect(points.count == 72)
    #expect(points.allSatisfy { rect.insetBy(dx: -0.001, dy: -0.001).contains($0) })
    #expect(PinkedSquare.points(in: rect, teeth: 0).count == 8)
}

@Test func theLongRuleChaptersAreReadAThoughtAtATimeInTheRulesOwnWords() {
    for chapter in [RulesView.Chapter.deal, .play] {
        let pieces = chapter.sections.map(\.text)
        #expect(pieces.count > 1)
        #expect(pieces.joined(separator: " ") == chapter.paragraphs.joined(separator: " "))
        #expect(pieces.allSatisfy { $0.hasSuffix(".") })
    }
    #expect(RulesView.Chapter.thoughts("One. Two.", sizes: [3]) == ["One. Two."])
}

@Test func aChaptersTopCardTurnsThroughTheFourSuitsWithItsNumber() {
    #expect((1...5).map(LayeredCards.suit) == ["♥", "♣", "♦", "♠", "♥"])
    #expect(LayeredCards.suit(for: 0) == "♠")
}

@Test func theRulebookHasThirteenPagesThatCoverAllSixChaptersInOrder() {
    #expect(Rulebook.pages.count == 13)
    #expect(Rulebook.pages.first?.chapter == nil)
    #expect(Set(Rulebook.pages.map(\.title)).count == 13)
    let chapters = Rulebook.pages.compactMap(\.chapter)
    #expect(chapters == chapters.sorted { $0.rawValue < $1.rawValue })
    #expect(Set(chapters) == Set(RulesView.Chapter.allCases))
    for chapter in RulesView.Chapter.allCases {
        #expect(Rulebook.pages[Rulebook.firstPage(of: chapter)].chapter == chapter)
        #expect(!Rulebook.about(chapter).isEmpty)
    }
}

@Test func theRulebookNamesItsOwnCastAndAnswersTheDealersCalls() {
    #expect(Rulebook.names == ["You", "Hazel", "Otto", "Rue"])
    #expect(Rulebook.verdict(forCall: .bid(3)).contains("may match"))
    #expect(Rulebook.verdict(forCall: .bid(4)).contains("beats the 3"))
    #expect(Rulebook.verdict(forCall: .bid(nil)).contains("Hazel"))
    // The engine, not the book, refuses a dealer's bid below the high bid, and allows a heart when hearts are led.
    var call = RuleTrial.make(.dealerMatch)
    if case .accepted = call.attempt(.bid(2)) { Issue.record("a dealer cannot bid under the high bid") }
    var hand = RuleTrial.make(.followSuit)
    if case .refused = hand.attempt(.play(Card(.hearts, .five))) { Issue.record("a heart follows a heart") }
}
