import Foundation
import Testing
@testable import CatchFive

private let saveDeck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }

private func readyMatch() throws -> Match {
    var match = try Match(deck: saveDeck, dealer: 3)
    try match.bid(seat: 0, amount: 2)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .hearts)
    return match
}

private func advance(_ match: inout Match, count: Int) throws {
    for _ in 0..<count {
        let seat = try #require(match.hand.nextSeat)
        let card = try #require(match.hand.legalMoves(seat: seat).first)
        try match.play(seat: seat, card: card)
    }
}

@Test func saveRestoresEveryPhaseAndContinuesIdentically() throws {
    var bidding = try Match(deck: saveDeck, dealer: 3)
    try bidding.bid(seat: 0, amount: 4)
    var resumedBid = try MatchSave.decode(MatchSave.encode(bidding))
    #expect(resumedBid.hand.auction.highestBid == 4)
    #expect(resumedBid.hand.nextSeat == 1)
    for seat in 1...3 { try resumedBid.bid(seat: seat, amount: nil) }
    let choosing = try MatchSave.decode(MatchSave.encode(resumedBid))
    #expect(choosing.hand.phase == .choosingTrump)
    #expect(choosing.hand.nextSeat == 0)

    for played in [0, 1, 3, 4, 23, 24] {
        var original = try readyMatch()
        try advance(&original, count: played)
        var restored = try MatchSave.decode(MatchSave.encode(original))
        #expect(restored.hand.hands == original.hand.hands)
        #expect(restored.hand.currentTrick == original.hand.currentTrick)
        #expect(restored.hand.nextSeat == original.hand.nextSeat)
        #expect(restored.hand.stock == original.hand.stock)
        #expect(restored.hand.discarded == original.hand.discarded)
        try advance(&original, count: 24 - played)
        try advance(&restored, count: 24 - played)
        #expect(restored.scores == original.scores)
        #expect(restored.hand.result == original.hand.result)
        #expect(restored.history.count == 1)
    }
}

@Test func saveRestoresHistoryAndNextDealer() throws {
    var match = try readyMatch()
    try advance(&match, count: 24)
    try match.startNextHand(deck: saveDeck)
    let restored = try MatchSave.decode(MatchSave.encode(match))
    #expect(restored.handNumber == 2)
    #expect(restored.hand.auction.dealer == 0)
    #expect(restored.history.count == 1)
    #expect(restored.scores == match.scores)
}

@Test func saveRoundTripOnDiskReplacesPreviousSave() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("match.json")
    var match = try readyMatch()
    try MatchSave.write(match, to: url)
    try advance(&match, count: 3)
    try MatchSave.write(match, to: url)
    let restored = try MatchSave.read(from: url)
    #expect(restored.hand.currentTrick.count == 3)
    #expect(restored.hand.nextSeat == 3)
    #expect(restored.hand.hands == match.hand.hands)
}

@Test func rejectsBrokenOrUnsupportedSave() throws {
    #expect(throws: SaveError.invalidData) { try MatchSave.decode(Data("broken".utf8)) }
    let match = try readyMatch()
    let data = try MatchSave.encode(match)
    var object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
    object["version"] = 999
    let future = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: SaveError.unsupportedVersion(999)) { try MatchSave.decode(future) }
}

@Test func diskFailuresAreReported() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        .appendingPathComponent("missing/match.json")
    let match = try readyMatch()
    #expect(throws: (any Error).self) { try MatchSave.write(match, to: url) }
    #expect(throws: (any Error).self) { try MatchSave.read(from: url) }
}

@Test func replayRejectsIllegalActionsAndInvalidInitialDeck() throws {
    let match = try readyMatch()
    var object = try #require(JSONSerialization.jsonObject(with: MatchSave.encode(match)) as? [String: Any])
    let illegal = try JSONEncoder().encode([SavedAction.bid(seat: 3, amount: 2)])
    object["actions"] = try JSONSerialization.jsonObject(with: illegal)
    let badAction = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: SaveError.invalidData) { try MatchSave.decode(badAction) }
    object["initialDeck"] = []
    let badDeck = try JSONSerialization.data(withJSONObject: object)
    #expect(throws: SaveError.invalidData) { try MatchSave.decode(badDeck) }
}

@Test func rejectedActionsNeverEnterSaveAndResavingDoesNotDuplicateActions() throws {
    var match = try readyMatch()
    let before = try MatchSave.encode(match)
    #expect(throws: RuleError.outOfTurn) { try match.play(seat: 1, card: Card(.clubs, .two)) }
    #expect(try MatchSave.encode(match) == before)
    var resumed = try MatchSave.decode(before)
    try advance(&resumed, count: 3)
    let saved = try MatchSave.encode(resumed)
    let restored = try MatchSave.decode(saved)
    #expect(try MatchSave.encode(restored) == saved)
    #expect(restored.hand.currentTrick.count == 3)
}

@Test func failedSaveKeepsThePreviousFileAndOneRetryWritesTheAcceptedMoveOnce() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer {
        try? FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        try? FileManager.default.removeItem(at: directory)
    }
    let url = directory.appendingPathComponent("match.json")
    var match = try readyMatch()
    try MatchSave.write(match, to: url)
    let previous = try Data(contentsOf: url)
    let previousActions = match.actionCount

    // The next move is accepted by the rules; the folder turns unwritable before it can be saved.
    try advance(&match, count: 1)
    #expect(match.actionCount == previousActions + 1)
    try FileManager.default.setAttributes([.posixPermissions: 0o500], ofItemAtPath: directory.path)
    #expect(throws: (any Error).self) { try MatchSave.write(match, to: url) }

    // The accepted move is still in memory, and the older save is intact rather than half written.
    #expect(match.actionCount == previousActions + 1)
    #expect(try Data(contentsOf: url) == previous)
    #expect(try MatchSave.read(from: url).actionCount == previousActions)

    // A retry writes exactly the state already in memory: the move is stored once, not replayed.
    try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
    try MatchSave.write(match, to: url)
    #expect(try Data(contentsOf: url) == MatchSave.encode(match))
    #expect(try MatchSave.read(from: url).actionCount == previousActions + 1)
    #expect(match.actionCount == previousActions + 1)

    // Saving the same match again is a replacement, never a second copy of the move.
    try MatchSave.write(match, to: url)
    let reread = try MatchSave.read(from: url)
    #expect(reread.actionCount == previousActions + 1)
    #expect(try MatchSave.encode(reread) == MatchSave.encode(match))
    #expect(reread.hand.hands == match.hand.hands)
    #expect(reread.hand.currentTrick == match.hand.currentTrick)
}

@Test func corruptSavesSurviveTheFailedReadSoTheyCanBeSetAside() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("match.json")

    // Nonsense in the save file, and a save cut short mid-write, are both refused.
    let nonsense = Data("not a game".utf8)
    try nonsense.write(to: url)
    #expect(throws: SaveError.invalidData) { try MatchSave.read(from: url) }
    #expect(try Data(contentsOf: url) == nonsense)   // reading never rewrites or clears the file

    let whole = try MatchSave.encode(readyMatch())
    let truncated = Data(whole.prefix(whole.count / 2))
    try truncated.write(to: url)
    #expect(throws: SaveError.invalidData) { try MatchSave.read(from: url) }
    #expect(try Data(contentsOf: url) == truncated)

    // Set the unreadable file aside, then start fresh: the new save is a clean match at hand one,
    // and the corrupt bytes are still there, byte for byte, to look at later.
    let aside = directory.appendingPathComponent("match-corrupt.json")
    try FileManager.default.moveItem(at: url, to: aside)
    try MatchSave.write(Match(deck: saveDeck, dealer: 3), to: url)
    let fresh = try MatchSave.read(from: url)
    #expect(fresh.actionCount == 0)
    #expect(fresh.hand.phase == .bidding)
    #expect(fresh.handNumber == 1 && fresh.scores == [0, 0] && fresh.history.isEmpty)
    #expect(try Data(contentsOf: aside) == truncated)
}
