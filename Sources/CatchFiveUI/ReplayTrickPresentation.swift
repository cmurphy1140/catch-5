import CatchFive
import Foundation

/// A local explanation of a recorded, completed trick. The engine remains the authority:
/// a missing card, duplicate seat or contradictory winner produces no invented explanation.
struct ReplayTrickPresentation: Equatable {
    let led: Suit
    let winningPlay: Play
    let rule: ReplayRule
    let explanation: String

    init?(plays: [Play], winner: Int, trump: Suit) {
        guard let actualWinner = try? trickWinner(plays, trump: trump),
              actualWinner == winner, let lead = plays.first,
              let winningPlay = plays.first(where: { $0.seat == winner }) else { return nil }

        let led = lead.card.suit
        self.led = led
        self.winningPlay = winningPlay
        let trumps = plays.filter { $0.card.suit == trump }
        if !trumps.isEmpty {
            rule = .trumpWins
            if let nextTrump = trumps.filter({ $0.seat != winner }).max(by: {
                $0.card.rank.rawValue < $1.card.rank.rawValue
            }) {
                explanation = "\(led.rawValue.capitalized) led. The \(winningPlay.card.name) was the highest trump, beating the \(nextTrump.card.name), so it took the trick."
            } else {
                explanation = "\(led.rawValue.capitalized) led. The \(winningPlay.card.name) was the only trump, so it took the trick."
            }
        } else {
            rule = .ledSuitWins
            let followers = plays.filter { $0.card.suit == led && $0.seat != winner }
            if let nextLed = followers.max(by: { $0.card.rank.rawValue < $1.card.rank.rawValue }) {
                explanation = "\(led.rawValue.capitalized) led and no trump was played. The \(winningPlay.card.name) was the highest card of the led suit, beating the \(nextLed.card.name), so it took the trick."
            } else {
                explanation = "\(led.rawValue.capitalized) led and no trump was played. The \(winningPlay.card.name) was the only card of the led suit, so it took the trick."
            }
        }
    }

    /// The fourth play already holds all four cards. Its immediately following award supplies
    /// the recorded winning seat, so the answer appears when the fourth card lands.
    static func forStep(_ step: ReplayStep, in replay: HandReplay) -> Self? {
        switch step.event {
        case let .trick(_, plays, winner):
            return Self(plays: plays, winner: winner, trump: replay.trump)
        case .play:
            guard step.currentTrick.count == 4,
                  let index = replay.steps.firstIndex(where: { $0.id == step.id }),
                  replay.steps.indices.contains(index + 1),
                  case let .trick(_, plays, winner) = replay.steps[index + 1].event,
                  plays == step.currentTrick else { return nil }
            return Self(plays: plays, winner: winner, trump: replay.trump)
        default:
            return nil
        }
    }

    /// Resolve by the recorded award and its first card, not by a guessed event offset.
    static func firstPlayStepID(number: Int, in replay: HandReplay) -> Int? {
        guard let awardIndex = replay.steps.firstIndex(where: {
            if case let .trick(trickNumber, _, _) = $0.event { return trickNumber == number }
            return false
        }), case let .trick(_, plays, _) = replay.steps[awardIndex].event,
              let lead = plays.first else { return nil }
        return replay.steps[..<awardIndex].reversed().first(where: {
            if case let .play(play) = $0.event { return $0.currentTrick.count == 1 && play == lead }
            return false
        })?.id
    }

    /// The live table's same orientation: bottom, left, across, right.
    static func seat(at place: Int, bottomSeat: Int) -> Int {
        ((bottomSeat + place) % 4 + 4) % 4
    }
}
