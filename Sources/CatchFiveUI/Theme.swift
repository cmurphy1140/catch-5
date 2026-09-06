import SwiftUI

/// Design tokens for the table. The numbers and their reasons are in docs/redesign-plan.md.
public enum Theme {
    public enum Card {
        /// Height over width: the 2:3 of today's cards, inside the 1:1.3–1:1.7 band real cards use.
        public static let ratio = 1.5
        /// Real cards round 3–4 mm on a 63 mm width, about six percent.
        public static func radius(width: Double) -> Double { width * 0.06 }
        public static let handWidth = 58.0
        public static let handWidthWide = 62.0
        public static let pileWidth = 62.0
        public static let backWidth = 40.0
        public static let tutorialWidth = 48.0
        /// Spacing between fanned hand cards; negative so they overlap.
        public static let handOverlap = -8.0
        /// Every overlapped card must still expose this much to a thumb.
        public static let minimumTouchStrip = 44.0
        public static let fanRotationDegrees = 8.0
        public static let fanDrop = 6.0
        public static let liftPlayable = 6.0
        public static let liftPressed = 6.0
        public static let pressedScale = 1.04
        public static let dimmedOpacity = 0.55
        /// An unavailable card stays solid: a dark veil over the face and most of its colour drained, so it
        /// reads as a card in shadow rather than a ghost showing the felt through it.
        public static let dimmedVeil = 0.38
        public static let dimmedSaturation = 0.35
        /// Under Increase Contrast the veil lightens and the dashed edge does the telling.
        public static let dimmedVeilHighContrast = 0.22
        /// Screens at least this wide (points) get the wider hand cards.
        public static let wideScreenWidth = 402.0
        /// Card faces stop scaling with Dynamic Type past this size; the surrounding text keeps scaling.
        public static let maximumTypeSize = DynamicTypeSize.xxxLarge

        /// The visible strip of each hand card at a given width.
        public static func touchStrip(width: Double) -> Double { width + handOverlap }
    }

    /// Text on the gameplay screen scales with Dynamic Type up to this size. Sheets scroll and stay uncapped.
    public static let maximumTableTypeSize = DynamicTypeSize.accessibility2
    /// Every text style in the app renders this many Dynamic Type steps above the system setting
    /// (the default Large becomes XXL), so the whole app reads larger while the user's setting still applies.
    public static let textBoostSteps = 2

    /// The oak table top drawn by `WoodGrainView`. Ivory text sits straight on it, so the base stays
    /// mid-dark (about 6:1 against ivory); the grain and the vignette carry the lighter, golden look.
    public enum Wood {
        public static let light = Color(red: 0.70, green: 0.51, blue: 0.29)
        public static let base = Color(red: 0.54, green: 0.37, blue: 0.20)
        public static let dark = Color(red: 0.38, green: 0.25, blue: 0.13)
        public static let streakLight = Color(red: 0.88, green: 0.72, blue: 0.48)
        public static let streakDark = Color(red: 0.24, green: 0.13, blue: 0.05)
        /// Dark inlay used for seat tiles, panels and the hand-end card so they sit on the wood.
        public static let inlay = Color(red: 0.12, green: 0.075, blue: 0.04)
        /// The darkest brown: tile edges and the shadow side of panels.
        public static let header = Color(red: 0.07, green: 0.045, blue: 0.025)
        /// Felt green for the playing area: echoes the card backs and sits apart from the oak header and tiles.
        public static let felt = Color(red: 0.10, green: 0.25, blue: 0.19)
        /// The lit centre of the felt, and its darkest edge.
        public static let feltEdge = Color(red: 0.16, green: 0.34, blue: 0.26)
        public static let feltDark = Color(red: 0.04, green: 0.13, blue: 0.10)
        /// The light flecks of the felt's nap, and the grid step (points) of the stipple.
        public static let feltLight = Color(red: 0.55, green: 0.80, blue: 0.62)
        public static let feltStipple = 4.0
        /// Grain runs across the screen (a board laid the long way under the phone) when true, top to bottom when false.
        public static let grainRunsHorizontally = true
        public static let seed: UInt64 = 11
        public static let bandCount = 28
        /// Points between grain lines, drawn at random within this range.
        public static let grainSpacing = 1.4...5.5
    }

    public enum Table {
        /// How far a played card is nudged from the pile's centre toward its seat.
        public static let sideNudge = 48.0
        public static let partnerNudge = 42.0
        public static let ownNudge = 42.0
        /// The pile's reserved footprint around a card, so the table does not jump between tricks.
        public static let pileMarginX = 64.0
        public static let pileMarginY = 48.0
        public static let seatBackWidth = 30.0
        public static let portraitSize = 36.0
        /// A played card lands with its own small turn and drift, like a card tossed in by hand.
        public static let tossRotationDegrees = 11.0
        public static let tossDrift = 6.0
        /// Seat tiles share one width; their height follows the phase (call text in the auction, backs in play).
        public static let seatTileWidth = 116.0
        /// The status-line glyph buttons (last trick, hint): hit area; the glyph itself has no plate.
        public static let statusButtonHitSize = 48.0
        /// The deck in the table's top-right corner.
        public static let deckWidth = 38.0
        /// How far above the fan the deck sits, for the deal-in flight.
        public static let deckRise = 520.0
        /// The discard pile sits this far below the deck; discards fly there when trump is named.
        public static let discardDrop = 72.0
        /// Bid, pass and suit pills: full column width, solid, well above the 44 pt minimum.
        public static let auctionButtonHeight = 64.0
        public static let auctionButtonSpacing = 6.0
        public static let auctionButtonRadius = 14.0
        /// The header band's bottom edge is a frown: the corners hang this much lower than the middle.
        public static let headerDip = 18.0
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
        /// After trump is named: discards rise toward the table and fade, then the refill deals in
        /// from the dealer's seat one card at a time.
        public static let discardRise = 240.0
        public static let discardStagger = 0.05
        public static let dealDelay = 0.35
        public static let dealStagger = 0.09
        /// The scheduler waits this long after trump is named before the first lead, so the deal finishes.
        public static let dealHold: Duration = .milliseconds(1400)
        /// How long the draw for dealer stays on the table before it puts itself away.
        public static let dealerDrawHold: Duration = .seconds(4)
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

public extension DynamicTypeSize {
    /// The size `steps` above this one, stopping at the largest accessibility size.
    func boosted(by steps: Int) -> DynamicTypeSize {
        let all = DynamicTypeSize.allCases
        guard let index = all.firstIndex(of: self) else { return self }
        return all[min(max(index + steps, 0), all.count - 1)]
    }
}
