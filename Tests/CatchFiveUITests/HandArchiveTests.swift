import CatchFive
@testable import CatchFiveUI
import Foundation
import Testing

private func archiveDeck(_ rotation: Int = 0) -> [Card] {
    let cards = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    return Array(cards[rotation...]) + Array(cards[..<rotation])
}

private func archiveFinishedMatch(lastCard: Bool = false) throws -> Match {
    var match = try Match(deck: archiveDeck(), dealer: 3)
    try match.bid(seat: 0, amount: 2)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .hearts)
    try archiveFinishPlay(&match, lastCard: lastCard)
    return match
}

private func archiveFinishPlay(_ match: inout Match, lastCard: Bool = false) throws {
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        let legal = match.hand.legalMoves(seat: seat)
        try match.play(seat: seat, card: try #require(lastCard ? legal.last : legal.first))
    }
}

private func archiveDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func archiveFiles(_ directory: URL) throws -> [String: Data] {
    var files: [String: Data] = [:]
    for name in try FileManager.default.subpathsOfDirectory(atPath: directory.path) {
        let url = directory.appendingPathComponent(name)
        guard try url.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile == true else { continue }
        files[name] = try Data(contentsOf: url)
    }
    return files
}

private func saveArchive(_ match: Match, in store: HandArchiveStore, date: Date = Date(timeIntervalSince1970: 100),
                         names: [String] = Settings.defaultSeatNames, mode: PlayMode = .solo,
                         recovered: Bool = false) throws -> ArchivedHand {
    try store.save(match, date: date, names: names, opponents: .friends, mode: mode,
                   difficulty: .standard, recovered: recovered)
}

@Test func archivedCompletionKeepsItsOriginalMetadataAndBytesWhenCapturedAgain() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HandArchiveStore(directory: directory)
    let match = try archiveFinishedMatch()
    let first = try saveArchive(match, in: store, date: Date(timeIntervalSince1970: 100.125))
    let original = try archiveFiles(directory)
    let again = try saveArchive(match, in: store, date: Date(timeIntervalSince1970: 500),
                                names: Array(repeating: "Renamed", count: 4), recovered: true)
    #expect(again.id == first.id && again.dealID == first.dealID)
    #expect(again.savedAt == first.savedAt && again.names == first.names && !again.recovered)
    #expect(try archiveFiles(directory) == original)
    let listing = try HandArchiveStore(directory: directory).entries()
    #expect(listing.entries.count == 1 && listing.unreadableFiles.isEmpty && !listing.hasMore)
    #expect(try MatchSave.encode(listing.entries[0].replay().finishedMatch) == MatchSave.encode(match))
}

@Test func archivedBranchesHaveSeparateCompletionIDsAndShareTheDealExclusion() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HandArchiveStore(directory: directory)
    let first = try saveArchive(archiveFinishedMatch(), in: store)
    let second = try saveArchive(archiveFinishedMatch(lastCard: true), in: store, date: Date(timeIntervalSince1970: 200))
    #expect(first.id != second.id && first.dealID == second.dealID)
    #expect(try store.entries().entries.map(\.id) == [second.id, first.id])
    let one = try store.entries(limit: 1)
    #expect(one.entries.map(\.id) == [second.id] && one.hasMore)
    #expect(try store.entries(excludingDealID: first.dealID).entries.isEmpty)
    #expect(try HandArchiveStore.dealIdentity(for: Match(deck: archiveDeck(), dealer: 3)) == first.dealID)
}

@Test func archivePreservesCorruptNeighborsAndRejectsAnInvalidExistingCompletion() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HandArchiveStore(directory: directory)
    let match = try archiveFinishedMatch()
    let saved = try saveArchive(match, in: store)
    let enumerator = try #require(FileManager.default.enumerator(at: directory, includingPropertiesForKeys: nil))
    let entry = try #require((enumerator.allObjects as? [URL])?.first { $0.lastPathComponent == saved.id + ".json" })
    let corrupt = entry.deletingLastPathComponent().appendingPathComponent("broken.json")
    let broken = Data("not an archive".utf8)
    try broken.write(to: corrupt)
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .secondsSince1970
    var invalid = try #require(JSONSerialization.jsonObject(with: encoder.encode(saved)) as? [String: Any])
    invalid["version"] = 99
    let unsupported = entry.deletingLastPathComponent().appendingPathComponent("unsupported.json")
    let unsupportedBytes = try JSONSerialization.data(withJSONObject: invalid)
    try unsupportedBytes.write(to: unsupported)
    let listing = try store.entries()
    #expect(listing.entries.map(\.id) == [saved.id] && listing.unreadableFiles.count == 2)
    #expect(try Data(contentsOf: corrupt) == broken)
    #expect(try Data(contentsOf: unsupported) == unsupportedBytes)
    try broken.write(to: entry)
    #expect(throws: (any Error).self) { try saveArchive(match, in: store) }
    #expect(try Data(contentsOf: entry) == broken)
}

@Test func archiveWriteFailureLeavesExistingHandFilesUntouched() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let archive = directory.appendingPathComponent("hands", isDirectory: true)
    let store = try HandArchiveStore(directory: archive)
    _ = try saveArchive(archiveFinishedMatch(), in: store)
    let files = try archiveFiles(archive)
    let kept = directory.appendingPathComponent("kept", isDirectory: true)
    try FileManager.default.moveItem(at: archive, to: kept)
    try Data("blocked".utf8).write(to: archive)
    #expect(throws: (any Error).self) { try saveArchive(archiveFinishedMatch(lastCard: true), in: store) }
    let after = try archiveFiles(kept)
    #expect(after.keys.sorted() == files.keys.sorted())
    for (name, bytes) in files { #expect(after[name] == bytes, "Preserve \(name)") }
}

@Test func archiveScopesKeepPriorPlayerFilesWhileStartingEmpty() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HandArchiveStore(directory: directory)
    let first = try saveArchive(archiveFinishedMatch(), in: store)
    let originalFiles = try archiveFiles(directory).filter { $0.key.contains(first.id) }
    try store.beginNewPlayer()
    #expect(try store.entries().entries.isEmpty)
    #expect(try HandArchiveStore(directory: directory).entries().entries.isEmpty)
    let currentFiles = try archiveFiles(directory)
    for (name, data) in originalFiles { #expect(currentFiles[name] == data) }
}

@MainActor @Test func modelRecoversAvailableHandsWithoutChangingLegacyFilesOrInventingOldDeals() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let game = directory.appendingPathComponent("game.json")
    let match = try archiveFinishedMatch()
    try MatchSave.write(match, to: game)
    try JSONEncoder().encode(PlayMode.solo).write(to: directory.appendingPathComponent("game-mode.json"))
    try SettingsStore.write(Settings(playerName: "Connor"), to: directory.appendingPathComponent("settings.json"))
    let legacy = MatchRecord(date: Date(timeIntervalSince1970: 1), scores: [25, 10], winner: 0, hands: 8,
                             difficulty: .easy, humanBids: 3, humanBidsMade: 2, humanPlays: 40, humanPlaysAgreed: 20)
    try MatchHistoryStore.write([legacy], to: directory.appendingPathComponent("history.json"))
    let original = try archiveFiles(directory)
    let model = GameModel.loadDefault(in: directory)
    let entries = model.savedHands().entries
    #expect(entries.count == 1 && entries[0].recovered)
    #expect(entries[0].names == model.seatNames)
    #expect(model.records == [legacy] && model.archiveStatistics.hands == 1)
    let after = try archiveFiles(directory)
    for (name, data) in original { #expect(after[name] == data) }
    let savedAt = entries[0].savedAt
    #expect(GameModel.loadDefault(in: directory).savedHands().entries.first?.savedAt == savedAt)
    model.newGame()
    #expect(model.savedHands().entries.count == 1)
    #expect(model.records == [legacy])
}

@MainActor @Test func modelArchiveCaptureAndRetryAreSeparateFromGamePersistence() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let archive = directory.appendingPathComponent("hands")
    let model = GameModel(match: try Match(deck: archiveDeck(), dealer: 3), mode: .passAndPlay, archiveDirectory: archive)
    while model.match.hand.phase != .finished {
        model.ready()
        switch model.match.hand.phase {
        case .bidding: model.send(model.match.hand.auction.highestBid == nil ? .bid(2) : .bid(nil))
        case .choosingTrump: model.send(.chooseTrump(.hearts))
        case .playing:
            let seat = try #require(model.match.hand.nextSeat)
            model.send(.play(try #require(model.match.hand.legalMoves(seat: seat).first)))
        case .finished: break
        }
    }
    #expect(model.savedHands().entries.count == 1)
    #expect(model.savedHands().entries.first?.recovered == false)
    #expect(model.records.isEmpty && model.archiveStatistics.soloHands == 0 && model.archiveStatistics.yourTricks == 0)
    let finished = try MatchSave.encode(model.match)
    model.retryArchive()
    #expect(model.savedHands().entries.count == 1 && model.archiveError == nil)
    #expect(try MatchSave.encode(model.match) == finished)
}

@MainActor @Test func modelResetPlayerStartsEmptyScopeAndKeepsPriorArchiveFiles() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    try MatchSave.write(archiveFinishedMatch(), to: directory.appendingPathComponent("game.json"))
    try SettingsStore.write(Settings(playerName: "Connor"), to: directory.appendingPathComponent("settings.json"))
    try MatchHistoryStore.write([], to: directory.appendingPathComponent("history.json"))
    let model = GameModel.loadDefault(in: directory)
    let original = model.savedHands().entries
    #expect(original.count == 1 && model.archiveStatistics.hands == 1)
    #expect(model.resetPlayer())
    #expect(model.savedHands().entries.isEmpty && model.archiveStatistics.hands == 0 && model.records.isEmpty)
    #expect(GameModel.loadDefault(in: directory).savedHands().entries.isEmpty)
    let allData = try archiveFiles(directory)
    #expect(allData.keys.contains { $0.contains(original[0].id) })
}

@MainActor @Test func failedArchiveScopeResetLeavesCurrentPlayerAndRealFilesUnchanged() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let archive = directory.appendingPathComponent("hands", isDirectory: true)
    let game = directory.appendingPathComponent("game.json")
    let settingsURL = directory.appendingPathComponent("settings.json")
    let history = directory.appendingPathComponent("history.json")
    let settings = Settings(playerName: "Connor")
    let model = GameModel(match: try archiveFinishedMatch(), saveURL: game, settings: settings,
                          settingsURL: settingsURL, historyURL: history, archiveDirectory: archive)
    model.persist()
    try SettingsStore.write(settings, to: settingsURL)
    try MatchHistoryStore.write(model.records, to: history)
    let oldMatch = try MatchSave.encode(model.match)
    let oldFiles = [game, settingsURL, history].map { try! Data(contentsOf: $0) }
    let oldArchive = try archiveFiles(archive)
    let kept = directory.appendingPathComponent("kept", isDirectory: true)
    try FileManager.default.moveItem(at: archive, to: kept)
    try Data("blocked".utf8).write(to: archive)
    #expect(!model.resetPlayer())
    #expect(model.settings == settings && model.archiveError != nil)
    #expect(try MatchSave.encode(model.match) == oldMatch)
    #expect([game, settingsURL, history].map { try! Data(contentsOf: $0) } == oldFiles)
    let after = try archiveFiles(kept)
    #expect(after.keys.sorted() == oldArchive.keys.sorted())
    for (name, bytes) in oldArchive { #expect(after[name] == bytes, "Preserve \(name)") }
}

@MainActor @Test func modelExcludesEveryArchivedBranchOfItsCurrentlyLiveDeal() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HandArchiveStore(directory: directory)
    _ = try saveArchive(archiveFinishedMatch(), in: store)
    _ = try saveArchive(archiveFinishedMatch(lastCard: true), in: store)
    let live = GameModel(match: try Match(deck: archiveDeck(), dealer: 3), archiveDirectory: directory)
    #expect(live.savedHands().entries.isEmpty && live.archiveStatistics.hands == 0)
    #expect(try store.entries().entries.count == 2)
}

@Test func archiveStatisticsDeduplicateCompletionsAndCountOnlySoloPlayersTricks() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try HandArchiveStore(directory: directory)
    let solo = try saveArchive(archiveFinishedMatch(), in: store)
    let shared = try saveArchive(archiveFinishedMatch(lastCard: true), in: store, mode: .passAndPlay)
    let stats = HandArchiveStatistics([solo, solo, shared])
    #expect(stats.hands == 2 && stats.soloHands == 1 && stats.yourTricks == solo.tricksWonBySeat[0])
}

@MainActor @Test func failedHandCaptureCanRetryAfterANewGameWithoutLosingItsOriginalReplay() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let archive = directory.appendingPathComponent("hands", isDirectory: true)
    let game = directory.appendingPathComponent("game.json")
    let model = GameModel(match: try Match(deck: archiveDeck(), dealer: 3), mode: .passAndPlay,
                          saveURL: game, archiveDirectory: archive)
    let kept = directory.appendingPathComponent("kept", isDirectory: true)
    try FileManager.default.moveItem(at: archive, to: kept)
    try Data("blocked".utf8).write(to: archive)
    while model.match.hand.phase != .finished {
        model.ready()
        switch model.match.hand.phase {
        case .bidding: model.send(model.match.hand.auction.highestBid == nil ? .bid(2) : .bid(nil))
        case .choosingTrump: model.send(.chooseTrump(.hearts))
        case .playing:
            let seat = try #require(model.match.hand.nextSeat)
            model.send(.play(try #require(model.match.hand.legalMoves(seat: seat).first)))
        case .finished: break
        }
    }
    let completed = try MatchSave.encode(model.match)
    #expect(model.archiveError != nil && model.saveError == nil)
    model.newGame()
    let currentGame = try Data(contentsOf: game)
    try FileManager.default.removeItem(at: archive)
    try FileManager.default.moveItem(at: kept, to: archive)
    model.retryArchive()
    let saved = try #require(model.savedHands().entries.first)
    #expect(saved.source == completed && !saved.recovered && model.archiveError == nil)
    #expect(try Data(contentsOf: game) == currentGame)
}

@MainActor @Test func coldArchiveFailureKeepsRecoveredCompletionMetadataAcrossANewGame() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let archive = directory.appendingPathComponent("hands", isDirectory: true)
    try Data("blocked".utf8).write(to: archive)
    let original = try archiveFinishedMatch()
    let source = try MatchSave.encode(original)
    let initialNames = ["Original", "Left", "Partner", "Right"]
    let settings = Settings(seatNames: initialNames, difficulty: .easy, playerName: "Original")
    let beforeInit = Date()
    let model = GameModel(match: original, settings: settings, archiveDirectory: archive)
    let afterInit = Date()
    #expect(model.archiveError != nil)
    model.now = { Date(timeIntervalSince1970: 500) }
    model.settings.seat(.family)
    model.settings.difficulty = .standard
    model.newGame()
    let current = try MatchSave.encode(model.match)
    try FileManager.default.removeItem(at: archive)
    model.retryArchive()
    let saved = try #require(model.savedHands().entries.first)
    #expect(saved.source == source && saved.recovered)
    #expect(saved.names == initialNames && saved.opponents == .friends && saved.difficulty == .easy)
    #expect(saved.savedAt >= beforeInit && saved.savedAt <= afterInit)
    #expect(model.archiveError == nil)
    #expect(try MatchSave.encode(model.match) == current)
}

@MainActor @Test func resetRefusesToDiscardPendingHandsBeforeStartingANewArchiveScope() throws {
    let directory = try archiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let archive = directory.appendingPathComponent("hands", isDirectory: true)
    let game = directory.appendingPathComponent("game.json")
    let settingsURL = directory.appendingPathComponent("settings.json")
    let history = directory.appendingPathComponent("history.json")
    let settings = Settings(playerName: "Connor")
    let model = GameModel(match: try Match(deck: archiveDeck(), dealer: 3), mode: .passAndPlay,
                          saveURL: game, settings: settings, settingsURL: settingsURL, historyURL: history,
                          archiveDirectory: archive)
    try SettingsStore.write(settings, to: settingsURL)
    try MatchHistoryStore.write([], to: history)
    let players = archive.appendingPathComponent("players", isDirectory: true)
    let scope = try #require(FileManager.default.contentsOfDirectory(at: players, includingPropertiesForKeys: nil).first)
    let expectedID = try HandArchiveStore.identity(for: archiveFinishedMatch())
    let blockedEntry = scope.appendingPathComponent(expectedID + ".json", isDirectory: true)
    try FileManager.default.createDirectory(at: blockedEntry, withIntermediateDirectories: false)
    while model.match.hand.phase != .finished {
        model.ready()
        switch model.match.hand.phase {
        case .bidding: model.send(model.match.hand.auction.highestBid == nil ? .bid(2) : .bid(nil))
        case .choosingTrump: model.send(.chooseTrump(.hearts))
        case .playing:
            let seat = try #require(model.match.hand.nextSeat)
            model.send(.play(try #require(model.match.hand.legalMoves(seat: seat).first)))
        case .finished: break
        }
    }
    #expect(model.archiveError != nil)
    let completed = try MatchSave.encode(model.match)
    let marker = archive.appendingPathComponent("player-scope.json")
    let paths = [game, settingsURL, history, marker]
    let before = try paths.map { try Data(contentsOf: $0) }
    try #require(!model.resetPlayer())
    #expect(model.settings == settings && model.archiveError != nil)
    #expect(try MatchSave.encode(model.match) == completed)
    #expect(try paths.map { try Data(contentsOf: $0) } == before)
    try FileManager.default.removeItem(at: blockedEntry)
    model.retryArchive()
    let saved = try #require(model.savedHands().entries.first)
    #expect(saved.source == completed)
    #expect(model.resetPlayer())
    #expect(model.savedHands().entries.isEmpty && model.archiveStatistics.hands == 0)
    #expect(FileManager.default.fileExists(atPath: scope.appendingPathComponent(expectedID + ".json").path))
}
