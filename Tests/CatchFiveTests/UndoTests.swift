import Foundation
import Testing
@testable import CatchFive

private func playedMatch() throws -> Match {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var match = try Match(deck: deck, dealer: 3)
    try match.bid(seat: 0, amount: 9)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    for _ in 0..<5 {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    return match
}

@Test func rewoundMatchEqualsFreshReplay() throws {
    let match = try playedMatch()
    #expect(match.actionCount == 10)
    let whole = try match.rewound(toActionCount: match.actionCount)
    #expect(try MatchSave.encode(whole) == MatchSave.encode(match))
    let partial = try match.rewound(toActionCount: 5)
    #expect(partial.actionCount == 5)
    #expect(partial.hand.phase == .playing && partial.hand.currentTrick.isEmpty)
    #expect(throws: (any Error).self) { try match.rewound(toActionCount: 99) }
}

@Test func undoDropsHumanActionAndComputerReplies() throws {
    let match = try playedMatch()   // 4 bids, trump, seat 0's lead, three replies, then the winner's lead
    let point = try #require(match.undoPoint(forSeat: 0))
    #expect(point == 5)   // just before seat 0's opening lead
    let undone = try match.rewound(toActionCount: point)
    #expect(undone.hand.nextSeat == 0 && undone.hand.completedTricks.isEmpty && undone.hand.hands[0].count == 6)
    // Undoing again steps back to before the trump choice, then to before the bid.
    let trump = try #require(undone.undoPoint(forSeat: 0))
    #expect(trump == 4)
    let choosing = try undone.rewound(toActionCount: trump)
    #expect(choosing.hand.phase == .choosingTrump && choosing.hand.nextSeat == 0)
    #expect(choosing.undoPoint(forSeat: 0) == 0)
    #expect(try choosing.rewound(toActionCount: 0).hand.phase == .bidding)
}

@Test func undoUnavailableAcrossHandBoundaryAndAfterScoring() throws {
    var match = try playedMatch()
    while match.hand.phase == .playing {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    #expect(match.hand.phase == .finished)
    #expect(match.undoPoint(forSeat: 0) == nil)
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    try match.startNextHand(deck: deck)
    #expect(match.undoPoint(forSeat: 0) == nil)   // nothing of seat 0's in this hand yet
    try match.bid(seat: 1, amount: nil)
    #expect(match.undoPoint(forSeat: 1) == match.actionCount - 1)
}

private func actingSeat(of action: SavedAction) -> Int? {
    switch action {
    case let .nineAndOut(seat), let .bid(seat, _), let .trump(seat, _), let .play(seat, _): return seat
    case .nextHand: return nil
    }
}

@Test func undoAfterAResumeTakesBackOneHumanTurnAndTheMatchSavesAndReloadsIdentically() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    let url = directory.appendingPathComponent("match.json")

    let match = try playedMatch()
    try MatchSave.write(match, to: url)
    let resumed = try MatchSave.read(from: url)
    #expect(try MatchSave.encode(resumed) == MatchSave.encode(match))

    // A resume keeps the undo boundary exactly where it was before the app closed.
    let point = try #require(resumed.undoPoint(forSeat: 0))
    #expect(point == match.undoPoint(forSeat: 0))
    #expect(actingSeat(of: resumed.actions[point]) == 0)
    #expect(resumed.actions.dropFirst(point + 1).allSatisfy { actingSeat(of: $0) != 0 })
    #expect(resumed.actionCount - point == 5)   // seat 0's lead and the four computer actions after it

    // Undoing on the resumed match takes back that turn and only what followed it.
    let undone = try resumed.rewound(toActionCount: point)
    #expect(undone.actionCount == point)
    #expect(undone.hand.nextSeat == 0)
    #expect(undone.hand.phase == .playing)
    #expect(undone.hand.currentTrick.isEmpty && undone.hand.completedTricks.isEmpty)
    #expect(undone.hand.hands[0].count == 6)
    #expect(try MatchSave.encode(undone) == MatchSave.encode(match.rewound(toActionCount: point)))

    // The undone match saves and reloads identically; nothing of the taken-back turn comes back.
    try MatchSave.write(undone, to: url)
    let reloaded = try MatchSave.read(from: url)
    #expect(try MatchSave.encode(reloaded) == MatchSave.encode(undone))
    #expect(reloaded.actionCount == point)
    #expect(reloaded.hand.hands == undone.hand.hands)
    #expect(reloaded.hand.currentTrick == undone.hand.currentTrick)
    #expect(reloaded.hand.stock == undone.hand.stock)
    #expect(reloaded.hand.discarded == undone.hand.discarded)
    #expect(reloaded.scores == undone.scores)

    // Seat 0 can now choose a different card, and the save records the new one only.
    var second = reloaded
    let choices = second.hand.legalMoves(seat: 0)
    #expect(choices.count > 1)
    let different = try #require(choices.last)
    #expect(different != resumed.hand.completedTricks.first?.plays.first?.card)
    try second.play(seat: 0, card: different)
    try MatchSave.write(second, to: url)
    let afterRedo = try MatchSave.read(from: url)
    #expect(afterRedo.actionCount == point + 1)
    #expect(afterRedo.hand.currentTrick.map(\.card) == [different])
    #expect(afterRedo.hand.hands[0].count == 5)
}
