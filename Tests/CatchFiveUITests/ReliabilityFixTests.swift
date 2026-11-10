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
