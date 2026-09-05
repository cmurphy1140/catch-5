import SwiftUI

/// Design tokens for the table. The numbers and their reasons are in docs/redesign-plan.md.
public enum Theme {
    public enum Card {
        /// Height over width: the 2:3 of today's cards, inside the 1:1.3–1:1.7 band real cards use.
        public static let ratio = 1.5
        /// Real cards round 3–4 mm on a 63 mm width, about six percent.
        public static func radius(width: Double) -> Double { width * 0.06 }
        public static let handWidth = 60.0
        public static let handWidthWide = 64.0
        public static let pileWidth = 56.0
        public static let backWidth = 40.0
        public static let tutorialWidth = 48.0
        /// Spacing between fanned hand cards; negative so they overlap.
        public static let handOverlap = -16.0
        /// Every overlapped card must still expose this much to a thumb.
        public static let minimumTouchStrip = 44.0
        public static let fanRotationDegrees = 8.0
        public static let fanDrop = 6.0
        public static let liftPlayable = 6.0
        public static let liftPressed = 6.0
        public static let pressedScale = 1.04
        public static let dimmedOpacity = 0.55

        /// The visible strip of each hand card at a given width.
        public static func touchStrip(width: Double) -> Double { width + handOverlap }
    }

    public enum Motion {
        public static let lift = Animation.spring(duration: 0.3, bounce: 0.15)
        public static let press = Animation.spring(duration: 0.2, bounce: 0.2)
        public static let flight = Animation.spring(duration: 0.45, bounce: 0)
        public static let arrive = Animation.spring(duration: 0.4, bounce: 0)
        public static let collapse = Animation.spring(duration: 0.5, bounce: 0)
        public static let overlay = Animation.spring(duration: 0.35, bounce: 0)
        /// Reduce Motion replaces every flight with this crossfade.
        public static let reduced = Animation.easeInOut(duration: 0.2)
        /// How long a finished trick stays on the table, winner ringed, before it collapses.
        public static let trickHold: Duration = .milliseconds(900)
        public static let shakeSeconds = 0.3
        public static let toastSeconds = 4.0
    }
}
