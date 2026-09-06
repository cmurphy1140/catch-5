import CatchFive
import Foundation

/// How a played card lands on the pile: its seat's nudge plus a small turn and drift of its own, as
/// if tossed in by hand. The pose is a pure function of the card, the hand and the trick, so it holds
/// still for as long as the trick lies on the table and comes out differently next time.
enum CardToss {
    struct Pose: Equatable {
        let rotation: Double   // degrees
        let offset: CGSize
    }

    static func pose(for card: Card, hand: Int, trick: Int) -> Pose {
        let suit = UInt64(Suit.allCases.firstIndex(of: card.suit) ?? 0)
        let seed = (UInt64(hand) &* 7919 &+ UInt64(trick) &* 131 &+ suit &* 17 &+ UInt64(card.rank.rawValue)) &* 2_654_435_761
        var random = GrainRandom(seed: seed)
        let rotation = random.next(in: -Theme.Table.tossRotationDegrees...Theme.Table.tossRotationDegrees)
        let dx = random.next(in: -Theme.Table.tossDrift...Theme.Table.tossDrift)
        let dy = random.next(in: -Theme.Table.tossDrift...Theme.Table.tossDrift)
        return Pose(rotation: rotation, offset: CGSize(width: dx, height: dy))
    }
}
