import CatchFive
@testable import CatchFiveUI
import Foundation
import Testing

private func learningDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func learningCompletedHand(rotation: Int = 0) throws -> Match {
    let cards = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let offset = rotation % cards.count
    let deck = Array(cards[offset...] + cards[..<offset])
    let dealer = rotation < 52 ? 3 : 2
    var match = try Match(deck: deck, dealer: dealer)
    let bidder = (dealer + 1) % 4
    try match.bid(seat: bidder, amount: 2)
    for position in 1...3 { try match.bid(seat: (bidder + position) % 4, amount: nil) }
    try match.chooseTrump(seat: bidder, suit: .clubs)
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    return match
}

private func learningFiles(_ directory: URL) throws -> [String: Data] {
    let enumerator = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: [.isRegularFileKey]))
    var result: [String: Data] = [:]
    for case let url as URL in enumerator where try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true {
        result[String(url.path.dropFirst(directory.path.count))] = try Data(contentsOf: url)
    }
    return result
}

@MainActor @Test func learningRoutesKeepRealGameAndFilesWhilePracticingArchivedDeal() async throws {
    let directory = try learningDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let archived = try learningCompletedHand()
    let real = GameModel(match: try Match(deck: PracticeDeal.mixed.deck(), dealer: 3),
        saveURL: directory.appendingPathComponent("game.json"), settings: Settings(playerName: "Connor"),
        settingsURL: directory.appendingPathComponent("settings.json"), historyURL: directory.appendingPathComponent("history.json"),
        archiveDirectory: directory.appendingPathComponent("hands"))
    real.persist()
    let store = try HandArchiveStore(directory: directory.appendingPathComponent("hands"))
    let entry = try store.save(archived, date: Date(timeIntervalSince1970: 12), names: ["Old", "Same", "Same", "Long historical name"],
                               opponents: .family, mode: .solo, difficulty: .easy)
    let source = try MatchSave.encode(real.match)
    let settings = real.settings
    let files = try learningFiles(directory)
    let flow = LearningFlowModel(real: real, start: .archive)
    await flow.load()
    #expect(flow.listing.entries.map(\.id) == [entry.id])
    #expect(flow.select(entry) && flow.path.last == .replay)
    flow.beginPractice()
    #expect(flow.path.last == .setup)
    flow.startPractice(PracticeConfiguration(left: .easy, partner: .standard, right: .easy))
    let firstPractice = try #require(flow.practiceModel)
    #expect(firstPractice !== real && firstPractice.isPractice && flow.path.last == .practice)
    #expect(firstPractice.match.hand.hands == (try entry.replay()).steps[0].hands)
    #expect(firstPractice.settings.seatNames == entry.names && firstPractice.settings.opponents == .family)
    flow.newPracticeDeal()
    #expect(flow.practiceModel !== firstPractice && flow.practiceModel?.isPractice == true)
    #expect(flow.practiceModel?.settings.seatNames == entry.names && flow.practiceModel?.settings.opponents == .family)
    #expect(flow.practiceModel?.match.hand.hands != firstPractice.match.hand.hands)
    #expect(!flow.leavePractice() && flow.path.last == .replay && flow.practiceModel == nil)
    #expect(try MatchSave.encode(real.match) == source && real.settings == settings && real.records.isEmpty)
    #expect(try learningFiles(directory) == files)
}

@MainActor @Test func directPracticeExitClosesWithoutReplacingTheRealMatch() async throws {
    let real = GameModel(match: try Match(deck: PracticeDeal.mixed.deck(), dealer: 3))
    let before = try MatchSave.encode(real.match)
    let flow = LearningFlowModel(real: real, start: .practice)
    flow.startPractice(PracticeConfiguration(deal: .trumpRich))
    #expect(flow.practiceModel?.match.hand.hands[0].filter { $0.suit == .hearts }.count == 6)
    #expect(flow.leavePractice() && flow.practiceModel == nil)
    #expect(try MatchSave.encode(real.match) == before)
}

@MainActor @Test func archiveSelectionCannotRevealAnActiveDealOrSurviveAPlayerReset() async throws {
    let directory = try learningDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let completed = try learningCompletedHand()
    let store = try HandArchiveStore(directory: directory)
    let entry = try store.save(completed, date: .now, names: Settings.defaultSeatNames, opponents: .friends, mode: .solo, difficulty: .standard)
    let live = GameModel(match: try HandReplay(match: completed).practiceMatch(), archiveDirectory: directory)
    let blocked = LearningFlowModel(real: live, start: .archive)
    await blocked.load()
    #expect(blocked.listing.entries.isEmpty && !blocked.select(entry) && blocked.selectedReplay == nil)
    let real = GameModel(match: try Match(deck: PracticeDeal.mixed.deck(), dealer: 3), archiveDirectory: directory)
    let flow = LearningFlowModel(real: real, start: .archive)
    await flow.load()
    #expect(flow.select(entry))
    #expect(real.resetPlayer())
    await flow.validateSelection()
    #expect(flow.selectedReplay == nil && flow.path.isEmpty)
}

@MainActor @Test func archiveSearchFindsAnOlderHandPastFirstPageAndKeepsSavedScopeStatistics() async throws {
    let directory = try learningDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HandArchiveStore(directory: directory)
    for index in 0..<55 {
        try store.save(learningCompletedHand(rotation: index), date: Date(timeIntervalSince1970: Double(index)),
                       names: [index == 0 ? "Needle player" : "Connor", "Left", "Partner", "Right"],
                       opponents: .friends, mode: index == 0 ? .passAndPlay : .solo, difficulty: .standard)
    }
    let real = GameModel(match: try Match(deck: PracticeDeal.mixed.deck(), dealer: 1), archiveDirectory: directory)
    let flow = LearningFlowModel(real: real, start: .archive)
    await flow.load()
    #expect(flow.listing.entries.count == 50 && flow.listing.hasMore)
    #expect(flow.statistics.hands == 55 && flow.statistics.soloHands == 54)
    flow.query = "needle"
    #expect(flow.listing.entries.count == 1 && flow.listing.entries.first?.names[0] == "Needle player")
    #expect(!flow.listing.hasMore)
    flow.query = ""
    flow.loadMore()
    #expect(flow.listing.entries.count == 55 && !flow.listing.hasMore)
}

@MainActor @Test func archiveFailureCanRetryWithoutChangingTheCurrentRouteOrRealGame() async throws {
    let directory = try learningDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocked = directory.appendingPathComponent("hands")
    try Data("unavailable".utf8).write(to: blocked)
    let real = GameModel(match: try Match(deck: PracticeDeal.mixed.deck(), dealer: 3), archiveDirectory: blocked)
    let before = try MatchSave.encode(real.match)
    let flow = LearningFlowModel(real: real, start: .archive)
    await flow.load()
    #expect(flow.error != nil && flow.listing.entries.isEmpty && flow.path.isEmpty)
    try FileManager.default.moveItem(at: blocked, to: directory.appendingPathComponent("preserved"))
    await flow.retry()
    #expect(flow.error == nil && flow.path.isEmpty)
    #expect(try MatchSave.encode(real.match) == before)
}

@MainActor @Test func failedPlayerResetNeverCallsTheMenuSignInTransition() async throws {
    let directory = try learningDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let blocked = directory.appendingPathComponent("hands")
    try Data("unavailable".utf8).write(to: blocked)
    let real = GameModel(match: try learningCompletedHand(), settings: Settings(playerName: "Connor"), archiveDirectory: blocked)
    let before = try MatchSave.encode(real.match)
    var transitions = 0
    #expect(!LearningFlowModel.resetPlayer(real, onSuccess: { transitions += 1 }))
    #expect(transitions == 0 && real.settings.playerName == "Connor" && real.archiveError != nil)
    #expect(try MatchSave.encode(real.match) == before)
    try FileManager.default.moveItem(at: blocked, to: directory.appendingPathComponent("preserved"))
    #expect(LearningFlowModel.resetPlayer(real, onSuccess: { transitions += 1 }))
    #expect(transitions == 1 && real.settings.playerName == nil)
}

@MainActor @Test func directCompletedReplayInvalidatesWhenTheRealMatchIsReplacedEvenWithoutANameChange() async throws {
    let match = try learningCompletedHand()
    let real = GameModel(match: match)
    let flow = LearningFlowModel(real: real, start: .replay(try HandReplay(match: match), names: real.seatNames, mode: .solo))
    #expect(flow.selectedReplay != nil)
    real.newGame()
    await flow.validateSelection()
    #expect(flow.selectedReplay == nil && flow.practiceModel == nil && flow.path.isEmpty)
}
