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
        /// Screens at least this wide (points) get the wider hand cards.
        public static let wideScreenWidth = 402.0
        /// Card faces stop scaling with Dynamic Type past this size; the surrounding text keeps scaling.
        public static let maximumTypeSize = DynamicTypeSize.xxxLarge

        /// The visible strip of each hand card at a given width.
        public static func touchStrip(width: Double) -> Double { width + handOverlap }
    }

    /// Text on the gameplay screen scales with Dynamic Type up to this size. Sheets scroll and stay uncapped.
    public static let maximumTableTypeSize = DynamicTypeSize.accessibility2

    public enum Table {
        /// How far a played card is nudged from the pile's centre toward its seat.
        public static let sideNudge = 30.0
        public static let partnerNudge = 22.0
        public static let ownNudge = 24.0
        /// The pile's reserved footprint around a card, so the table does not jump between tricks.
        public static let pileMarginX = 64.0
        public static let pileMarginY = 48.0
        public static let seatBackWidth = 22.0
        public static let portraitSize = 28.0
    }

    public enum Motion {
        public static let press = Animation.spring(duration: 0.2, bounce: 0.2)
        public static let flight = Animation.spring(duration: 0.45, bounce: 0)
        public static let collapse = Animation.spring(duration: 0.5, bounce: 0)
        public static let overlay = Animation.spring(duration: 0.35, bounce: 0)
        /// Reduce Motion replaces every flight with this crossfade.
        public static let reduced = Animation.easeInOut(duration: 0.2)
        /// How long a finished trick stays on the table, winner ringed, before it collapses.
        public static let trickHold: Duration = .milliseconds(900)
        public static let shakeAmplitude = 6.0
        public static let toastSeconds = 4.0
    }

    /// Colours for drawn faces, chosen to sit with felt and ivory. No gold here (D33).
    public enum Portrait {
        public static func color(_ skin: CatchFiveUI.Portrait.Skin) -> Color {
            switch skin {
            case .light: Color(red: 0.96, green: 0.85, blue: 0.74)
            case .tan: Color(red: 0.85, green: 0.68, blue: 0.52)
            case .brown: Color(red: 0.62, green: 0.44, blue: 0.30)
            case .deep: Color(red: 0.38, green: 0.25, blue: 0.17)
            }
        }
        public static func color(_ hair: CatchFiveUI.Portrait.HairColor) -> Color {
            switch hair {
            case .black: Color(red: 0.12, green: 0.10, blue: 0.10)
            case .brown: Color(red: 0.40, green: 0.26, blue: 0.16)
            case .blond: Color(red: 0.80, green: 0.62, blue: 0.32)
            case .silver: Color(red: 0.80, green: 0.80, blue: 0.82)
            case .red: Color(red: 0.70, green: 0.30, blue: 0.16)
            }
        }
        public static func color(_ shirt: CatchFiveUI.Portrait.Shirt) -> Color {
            switch shirt {
            case .plum: Color(red: 0.42, green: 0.20, blue: 0.36)
            case .olive: Color(red: 0.40, green: 0.44, blue: 0.22)
            case .teal: Color(red: 0.16, green: 0.42, blue: 0.44)
            case .rust: Color(red: 0.62, green: 0.30, blue: 0.18)
            case .navy: Color(red: 0.16, green: 0.22, blue: 0.40)
            case .mustard: Color(red: 0.72, green: 0.58, blue: 0.22)
            }
        }
        /// Hats and glasses frames.
        public static let accessory = Color(red: 0.20, green: 0.20, blue: 0.22)
        public static let disc = Color(red: 0.10, green: 0.24, blue: 0.20)
        /// The flower hat.
        public static let blossom = Color(red: 0.93, green: 0.55, blue: 0.62)
    }
}
