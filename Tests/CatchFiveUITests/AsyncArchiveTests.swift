import CatchFive
@testable import CatchFiveUI
import Foundation
import Testing

private final class ArchiveReadGate: @unchecked Sendable {
    private let condition = NSCondition()
    private var started = false
    private var released = false
    private var mainThread = false
    let fails: Bool
    init(fails: Bool = false) { self.fails = fails }
    var hasStarted: Bool { condition.lock(); defer { condition.unlock() }; return started }
    var usedMainThread: Bool { condition.lock(); defer { condition.unlock() }; return mainThread }
    func read(_ request: HandArchiveReadRequest) throws -> HandArchiveListing {
        condition.lock()
        mainThread = Thread.isMainThread
        started = true
        condition.broadcast()
        while !released { condition.wait() }
        condition.unlock()
        if fails { throw CocoaError(.fileReadUnknown) }
        return try request.read()
    }
    func release() { condition.lock(); released = true; condition.broadcast(); condition.unlock() }
}

private func asyncArchiveDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

private func asyncCompletedMatch() throws -> Match {
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

@MainActor private func asyncReal(_ directory: URL) throws -> GameModel {
    GameModel(match: try asyncCompletedMatch(), settings: Settings(playerName: "Connor"), archiveDirectory: directory)
}

@MainActor @Test func asyncArchiveValidationRunsOffMainActorWhileTheMainActorCanWork() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let gate = ArchiveReadGate()
    let task = Task { await real.savedHandsAsync(limit: .max, reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    var actorProbe = false
    await Task { @MainActor in actorProbe = true }.value
    #expect(actorProbe && !gate.usedMainThread)
    gate.release()
    let listing = await task.value
    #expect(listing?.entries.count == 1)
    #expect(listing?.entries.map(\.id) == real.savedHands(limit: .max).entries.map(\.id))
}

@MainActor @Test func oldArchiveReadCannotPublishResultsOrErrorsAfterAPlayerScopeReset() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let gate = ArchiveReadGate(fails: true)
    let old = Task { await real.savedHandsAsync(limit: .max, reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    #expect(real.resetPlayer())
    let current = await real.savedHandsAsync(limit: .max)
    gate.release()
    #expect(await old.value == nil)
    #expect(current?.entries.isEmpty == true && real.archiveError == nil)
}

@MainActor @Test func oldArchiveReadCannotPublishAfterTheActiveDealChanges() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let gate = ArchiveReadGate()
    let old = Task { await real.savedHandsAsync(limit: .max, reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    real.newGame()
    gate.release()
    #expect(await old.value == nil)
}

@MainActor @Test func flowOverlappingArchiveLoadsAndCancellationCannotRestoreStaleState() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let flow = LearningFlowModel(real: real, start: .archive)
    let gate = ArchiveReadGate(fails: true)
    let old = Task { await flow.load(reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    #expect(flow.isLoading)
    flow.query = "hearts"
    #expect(flow.query == "hearts")
    await flow.load()
    #expect(!flow.isLoading && flow.listing.entries.count == 1 && flow.error == nil)
    gate.release()
    await old.value
    #expect(!flow.isLoading && flow.listing.entries.count == 1 && flow.error == nil)
    let closingGate = ArchiveReadGate()
    let closing = Task { await flow.load(reader: closingGate.read) }
    while !closingGate.hasStarted { await Task.yield() }
    closing.cancel()
    flow.cancelLoad()
    #expect(!flow.isLoading)
    closingGate.release()
    await closing.value
    #expect(!flow.isLoading && flow.error == nil)
}

@MainActor @Test func flowClearsRevealedOldPlayerCardsAndCountsBeforeWaitingForReload() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let flow = LearningFlowModel(real: real, start: .archive)
    await flow.load()
    #expect(flow.select(try #require(flow.listing.entries.first)))
    #expect(real.resetPlayer())
    let gate = ArchiveReadGate()
    let reload = Task { await flow.validateSelection(reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    #expect(flow.isLoading && flow.selectedReplay == nil && flow.listing.entries.isEmpty && flow.statistics.hands == 0)
    gate.release()
    await reload.value
    #expect(!flow.isLoading && flow.selectedReplay == nil && flow.listing.entries.isEmpty)
}

@MainActor @Test func savedStatisticsLoadingCanCancelWithoutPublishingOldPlayerCounts() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let statistics = SavedHandStatisticsModel()
    let gate = ArchiveReadGate()
    let pending = Task { await statistics.load(real, reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    #expect(statistics.isLoading)
    #expect(real.resetPlayer())
    await statistics.load(real)
    #expect(!statistics.isLoading && statistics.statistics.hands == 0)
    gate.release()
    await pending.value
    #expect(!statistics.isLoading && statistics.statistics.hands == 0 && statistics.error == nil)
}

@MainActor @Test func alreadyCancelledArchiveCallerCannotObsoleteAValidRead() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let gate = ArchiveReadGate()
    let valid = Task { await real.savedHandsAsync(limit: .max, reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    let cancelled = Task { await real.savedHandsAsync(limit: .max) }
    cancelled.cancel() // MainActor cannot start this task before the current turn yields below.
    #expect(await cancelled.value == nil)
    gate.release()
    #expect(await valid.value?.entries.count == 1)
    #expect(real.archiveError == nil)
}

@MainActor @Test func alreadyCancelledFlowCallerCannotCancelTheCurrentLoadOrItsIndicator() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let flow = LearningFlowModel(real: real, start: .archive)
    let gate = ArchiveReadGate()
    let valid = Task { await flow.load(reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    let cancelled = Task { await flow.load() }
    cancelled.cancel()
    await cancelled.value
    #expect(flow.isLoading)
    gate.release()
    await valid.value
    #expect(!flow.isLoading && flow.listing.entries.count == 1 && flow.error == nil)
}

@MainActor @Test func alreadyCancelledStatisticsCallerCannotCancelTheCurrentLoadOrItsIndicator() async throws {
    let directory = try asyncArchiveDirectory()
    defer { try? FileManager.default.removeItem(at: directory) }
    let real = try asyncReal(directory)
    let statistics = SavedHandStatisticsModel()
    let gate = ArchiveReadGate()
    let valid = Task { await statistics.load(real, reader: gate.read) }
    while !gate.hasStarted { await Task.yield() }
    let cancelled = Task { await statistics.load(real) }
    cancelled.cancel()
    await cancelled.value
    #expect(statistics.isLoading)
    gate.release()
    await valid.value
    #expect(!statistics.isLoading && statistics.statistics.hands == 1 && statistics.error == nil)
}
