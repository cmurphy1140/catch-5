import Foundation
import Testing
import CatchFive
@testable import CatchFiveUI

// Guards the reliability/feedback fixes from the 2026-10-31 audit.

@Test func unmappedErrorsDoNotLeakRawEnumText() {
    // Internal invariants ("cannot happen" errors) must never surface raw case names to a player.
    for error in [RuleError.invalidScoring, RuleError.invalidTrick, HandError.invalidDeck] as [any Error] {
        let message = GameModel.message(for: error)
        #expect(!message.contains("Error"))
        #expect(!message.lowercased().contains("invalid"))
    }
    // A mapped error still reads in plain words.
    #expect(GameModel.message(for: HandError.mustFollowSuit).contains("follow suit"))
}

@Test func passAndPlayMatchEndIsAlwaysAWin() {
    // No "you" in pass and play: whichever team reaches 25 has won, so neither fires the loss cue.
    #expect(TableFeedback.cue(action: nil, trickWinner: nil, handEnded: false, matchWinner: 1, mode: .passAndPlay) == .matchWon)
    #expect(TableFeedback.cue(action: nil, trickWinner: nil, handEnded: false, matchWinner: 0, mode: .passAndPlay) == .matchWon)
}

@Test func soloMatchEndReflectsTheHumanResult() {
    #expect(TableFeedback.cue(action: nil, trickWinner: nil, handEnded: false, matchWinner: 0, mode: .solo) == .matchWon)
    #expect(TableFeedback.cue(action: nil, trickWinner: nil, handEnded: false, matchWinner: 1, mode: .solo) == .matchLost)
}

@MainActor @Test func startingOverAsANewPlayerClearsNameMatchAndRecords() throws {
    // D108: the reset behind Settings leaves nobody signed in, a fresh untouched solo match and no statistics.
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let record = MatchRecord(date: Date(), scores: [25, 10], winner: 0, hands: 6, difficulty: .standard,
                             humanBids: 2, humanBidsMade: 1, humanPlays: 36, humanPlaysAgreed: 30)
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3), records: [record], historyURL: url)
    model.signIn(name: "Stacy", portrait: Cast.playerChoices[1], difficulty: .easy)
    model.send(.bid(9))
    #expect(model.matchInProgress && model.statistics.matches == 1)
    model.resetPlayer()
    #expect(!model.settings.hasSignedIn)
    #expect(model.settings.seatNames[0] == Settings.defaultSeatNames[0])
    #expect(model.settings.playerPortrait == Cast.defaultPlayerPortrait)
    #expect(!model.matchInProgress && model.mode == PlayMode.solo)
    #expect(model.statistics.matches == 0)
    #expect(try MatchHistoryStore.read(from: url).isEmpty)
}
