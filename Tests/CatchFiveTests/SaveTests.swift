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
