import SwiftUI

/// One haptic per accepted action. A single tap can play a card, take the trick, end the hand and win
/// the match; stacking four cues turns into a buzz, so the most consequential outcome speaks alone.
enum TableFeedback {
    enum HumanAction { case play, call }

    enum Cue: Equatable {
        case call, play, trickLost, trickWon, handEnded, matchLost, matchWon

        var feedback: SensoryFeedback {
            switch self {
            case .call: .selection
            case .play: .impact(flexibility: .soft, intensity: 0.6)
            case .trickLost: .impact(weight: .light, intensity: 0.7)
            case .trickWon: .impact(weight: .medium, intensity: 0.9)
            case .handEnded: .impact(weight: .medium)
            case .matchLost: .error
            case .matchWon: .success
            }
        }
    }

    /// `trickWinner` is the seat that just took a trick, if one completed; `matchWinner` the team that
    /// just won. Seats 0 and 2 are the human's team.
    static func cue(action: HumanAction?, trickWinner: Int?, handEnded: Bool, matchWinner: Int?) -> Cue? {
        if let matchWinner { return matchWinner == 0 ? .matchWon : .matchLost }
        if handEnded { return .handEnded }
        if let trickWinner { return trickWinner % 2 == 0 ? .trickWon : .trickLost }
        switch action {
        case .play: return .play
        case .call: return .call
        case nil: return nil
        }
    }
}
