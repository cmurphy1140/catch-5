import SwiftUI

/// Design tokens for the table. The numbers and their reasons are in docs/redesign-plan.md.
public enum Theme {
    public enum Card {
        /// Height over width: a poker card's 2.5 × 3.5 in (D97), inside the 1:1.3–1:1.7 band real cards use.
        public static let ratio = 1.4
        /// Real cards round 3–4 mm on a 63 mm width, about six percent.
        public static func radius(width: Double) -> Double { width * 0.06 }
        /// Hand cards a little larger than the pile's neighbours once were, so the hand reads as the thing you hold (D97).
        public static let handWidth = 64.0
        public static let handWidthWide = 70.0
        public static let pileWidth = 66.0
        public static let backWidth = 40.0
        public static let tutorialWidth = 48.0
        /// Spacing between fanned hand cards; negative so they overlap.
        public static let handOverlap = -12.0
        /// Every overlapped card must still expose this much to a thumb.
        public static let minimumTouchStrip = 44.0
        public static let fanRotationDegrees = 8.0
        public static let fanDrop = 6.0
        /// A legal card on your turn stands up out of the hand; an illegal one sinks a little into it (D97).
        public static let liftPlayable = 10.0
        public static let sinkDimmed = 4.0
        public static let liftPressed = 6.0
        /// The card you have picked rises clear of the fan, waiting for the second tap (D97).
        public static let liftSelected = 30.0
        /// Dragging a card up this far plays it; any less and it springs back into the hand.
        public static let dragToPlay = 70.0
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
        /// How far a played card sits from the pile's centre toward its seat: far enough that no two cards
        /// touch, even after their toss (T10). Side cards clear each other; top and bottom clear the sides.
        public static let sideNudge = Card.pileWidth / 2 + 13
        /// Top and bottom sit just over a card's height out, so the trick fits the field (D97); the pile scales these
        /// with the cards themselves, which grow with the reader's text size.
        public static let partnerNudge = Card.pileWidth * Card.ratio + 12
        public static let ownNudge = Card.pileWidth * Card.ratio + 12
        /// The pile's reserved footprint around a card, so the table does not jump between tricks.
        public static let pileMarginX = 64.0
        public static let pileMarginY = 48.0
        /// The height a seat's badge band keeps under the face, the height the old stack of backs had (spec R20),
        /// so the tiles do not jump when the dealer's mark moves on; the stack itself is gone (D93).
        public static let seatBackWidth = 14.0
        /// Faces around the table read at a glance from arm's length: 68 pt, a fifth smaller than the 86 of N48
        /// so the table breathes (D93), and still up from the 36 they started at (spec R2). At rest face and halo
        /// fit a side tile beside the pile; at full breath the halo borrows the gap beside it.
        public static let portraitSize = 68.0
        /// Room kept above a table face's disc, as a fraction of its size, for the head that pops out (N49).
        public static let portraitHeadroom = 0.24
        /// While bidding the side seats rise this far toward the partner's row, so the bigger faces still leave the
        /// bid pills and Pass above the hand (N48); no further, so they stay clear of the partner's row.
        public static let biddingSideRise = 36.0
        /// The tutorial's lesson tiles keep the smaller face so three of them still share a row.
        public static let tutorialPortraitSize = 36.0
        /// The seat to act wears a gold halo: a ring this wide, this far outside the portrait, that pulses
        /// gently to `activePulseScale` unless motion is reduced (spec R2).
        public static let activeRingWidth = 3.0
        public static let activeRingGap = 3.0
        public static let activePulseScale = 1.05
        /// A face drawn larger for a big public moment: the five of trump caught, a 9 and out declared (N36).
        /// 1.15 of the bigger face (N48) is still larger than the 1.3 of the old one, and stays clear of the pile.
        public static let bigMomentScale = 1.15
        /// A played card lands with its own small turn and drift, like a card tossed in by hand.
        public static let tossRotationDegrees = 4.0
        public static let tossDrift = 6.0
        /// Seat tiles share one width; their height follows the phase (call text in the auction, backs in play).
        public static let seatTileWidth = 116.0
        /// Air between the header's edge and the partner's halo; the seats hold the top of the table (spec R25).
        public static let seatInset = 6.0
        /// The status-line glyph buttons (last trick, hint): hit area; the glyph itself has no plate.
        public static let statusButtonHitSize = 44.0
        /// The deck in the table's top-right corner.
        public static let deckWidth = 38.0
        /// The dealer's mark (T12, N65): its deck's card width and the mark's width; and the partner's, set out this far
        /// beside their tile and this far down, clear of their card on the pile and under the scorecard.
        public static let dealerMarkDeckWidth = 30.0
        public static let dealerMarkWidth = 72.0
        /// The dealer button (D94): a puck a thumb wide, its "D" engraved large.
        public static let dealerButtonSize = 44.0
        public static let dealerButtonLetterSize = 24.0
        public static let partnerMarkGap = 6.0
        public static let partnerMarkDrop = 64.0
        /// How far above the fan the deck sits, for the deal-in flight.
        public static let deckRise = 520.0
        /// Each seat's box in the auction (N55): small enough that the side seats' boxes both fit between them,
        /// with a number big enough to read from arm's length and PASS or 9 OUT a size down so they still fit.
        public static let bidBoxWidth = 58.0
        public static let bidBoxHeight = 46.0
        public static let bidBoxRadius = 10.0
        public static let bidBoxNumberSize = 32.0
        public static let bidBoxWordSize = 20.0
        /// How far a side seat's box tucks into the seat's own tile, toward the empty middle of the table.
        public static let bidBoxTuck = 14.0
        /// The hand-end card and the demo caption stand in this far from the table's sides.
        public static let overlayInset = 12.0
        /// The score sheet's filled dots, layered green: a light fill with a mid-green edge and dark green digits.
        public static let dotInk = Color(red: 0.05, green: 0.17, blue: 0.10)
        public static let dotFill = Color(red: 0.52, green: 0.80, blue: 0.52)
        public static let dotFillEdge = Color(red: 0.26, green: 0.55, blue: 0.30)
        /// Every name carved into the wood under its seat (D94), and the phone holder's under the hand: large enough
        /// to read from across the table.
        public static let carvedNameSize = 22.0
        /// The layout runs under the bottom safe area and stops this far above the screen's edge, clear of its rounded corners.
        public static let footInset = 16.0
        /// The scorecard (N66): the ruled line's height, the handwritten total's size, and how many lines show.
        public static let scorecardRule = 26.0
        public static let scorecardNumberSize = 22.0
        public static let scorecardLines = 3
        /// Bid, pass and suit pills: full column width, solid, well above the 44 pt minimum.
        public static let auctionButtonHeight = 64.0
        /// Bid pills when they wrap to two rows, and Pass, sit this tall instead, so the whole auction fits above the
        /// hand on an iPhone 16 (D97); still well above the 44 pt minimum.
        public static let auctionButtonCompactHeight = 54.0
        public static let auctionButtonSpacing = 6.0
        public static let auctionButtonRadius = 14.0
        /// The slim row across the top (D93): Home on the left, Rules on the right, each a full thumb tall; the Rules
        /// book is this wide (D94).
        public static let topRowHeight = 44.0
        /// The book grew in D98 and again in D100, once the score pad left the row: it reads as something to pick up. It is
        /// taller than the row and overhangs it a little above and below, so the table keeps its height.
        public static let rulesBookWidth = 156.0
        public static let rulesBookHeight = 50.0
        /// The header band's bottom edge is a frown: the corners hang this much lower than the middle.
        public static let headerDip = 18.0
        /// The table's top corners either side of the partner (D65): the contract plaque on the left, the
        /// trump tile with the player's tally on the right. One size for both (N51), as wide as the row allows
        /// up to this (`TableLayout.cornerWidth(available:)`), so with the partner they nearly fill the row.
        public static let cornerWidth = 124.0
        public static let cornerHeight = 116.0
        public static let cornerRadius = 14.0
        /// The score pad's paper is a very light tan (D76); the bid corner has no fill and is carved into the wood (D94).
        public static let cornerFill = Color(red: 0.91, green: 0.84, blue: 0.70)
        /// Big for people who won't read small text (N52): the bid's number in the display serif, the bidder's
        /// face beside it, and trump under them in the same box (N63).
        public static let plaqueNumberSize = 52.0
        public static let plaquePortraitSize = 46.0
        public static let bidBoxSuitSize = 48.0
        /// Trump set with its word on one line in the bid corner, "♠ Trump" (D95), the tally under the line; the line and
        /// the tally together keep the `bidBoxSuitSize` row.
        public static let trumpLineSuitSize = 28.0
        /// The carved back arrow that stands for Home in the top row (D95).
        public static let homeArrowSize = 26.0
        /// The word Trump over the tally, beside the suit (D93), and BID over the number, both carved and readable (D94).
        public static let trumpWordSize = 16.0
        public static let bidEyebrowSize = 15.0
        /// A corner arrives (N53): it grows from this scale with a glow that fades over `cornerGlowSeconds`.
        public static let cornerArrivalScale = 0.6
        public static let cornerGlowSeconds = 0.9
        /// Tally strokes chalked beside the carved suit (D94): height, the step between strokes, and the gap between groups of five.
        public static let tallyHeight = 24.0
        public static let tallyStep = 4.0
        public static let tallyGroupGap = 7.0
        /// The bidder's seat wears a dashed light-brown ring on the portrait's own edge, inside where the
        /// gold halo of the seat to act would sit, so the two never read as one another.
        public static let bidderRingWidth = 2.5
        public static let bidderRingDash: [CGFloat] = [5, 3]
        /// The player's out-of-trump mark: an ivory disc on the portrait's lower-left, the suit crossed out.
        public static let outOfTrumpBadgeSize = 26.0
    }

    /// The playing field (D97): a walnut panel inlaid in the oak where the trick lands, framed by a maple stringing
    /// line and recessed under its top edge. Cream cards sit on it at well over 7:1.
    public enum Field {
        public static let walnut = Color(red: 0.25, green: 0.155, blue: 0.09)
        public static let walnutLight = Color(red: 0.33, green: 0.21, blue: 0.12)
        public static let walnutDark = Color(red: 0.15, green: 0.09, blue: 0.05)
        /// The stringing: a strip of maple set into the walnut just inside its edge, with a dark seam either side.
        public static let maple = Color(red: 0.86, green: 0.74, blue: 0.53)
        public static let stringingInset = 7.0
        public static let stringingWidth = 1.6
        public static let cornerRadius = 26.0
        /// How far the field reaches under each side seat's tile (just to the rim of its portrait, clear of its carved
        /// name), and the air above and below it.
        public static let sideTuck = 2.0
        public static let verticalGap = 6.0
        /// Trump inlaid at the field's centre once it is named: maple for black suits, a red wood for red ones.
        public static let inlayRed = Color(red: 0.74, green: 0.27, blue: 0.18)
        public static let inlayOpacity = 0.68
        public static let inlayMaximum = 116.0
        /// The pool of lamplight that sits in front of the seat to act.
        public static let lamp = Color(red: 1.0, green: 0.88, blue: 0.62)
        public static let lampOpacity = 0.26
    }

    /// Which side a seat is on, worn as the rim of its portrait (D97): your team's light, the opponents' oxblood.
    public enum Team {
        public static let ourRim = Color(red: 0.95, green: 0.90, blue: 0.78)
        public static let theirRim = Color(red: 0.50, green: 0.09, blue: 0.11)
        public static let rimWidth = 3.5
    }

    public enum Motion {
        public static let press = Animation.spring(duration: 0.2, bounce: 0.2)
        public static let flight = Animation.spring(duration: 0.45, bounce: 0)
        public static let collapse = Animation.spring(duration: 0.5, bounce: 0)
        public static let overlay = Animation.spring(duration: 0.35, bounce: 0)
        /// One beat of a rules figure playing in as its chapter arrives: quick, with a little bounce (D107).
        public static let arrival = Animation.spring(duration: 0.4, bounce: 0.3)
        /// Reduce Motion replaces every flight with this crossfade.
        public static let reduced = Animation.easeInOut(duration: 0.2)
        /// The halo on the seat to act breathes in and out for as long as that seat is deciding.
        public static let pulse = Animation.easeInOut(duration: 1.2).repeatForever(autoreverses: true)
        public static let shakeAmplitude = 6.0
        public static let toastSeconds = 4.0
        /// How long the table's "bidding bolder" note stays before it fades (D71).
        public static let boldNoteSeconds = 3.0
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
        /// The one beat before a computer plays or a finished hand is collected, so each can be read (T11). Tune here.
        public static let botBeat: Duration = .seconds(2)

        /// Flights (D97). A played card travels from the player to its spot on the field.
        public static let playSeconds = 0.42
        /// A finished trick gathers onto the winning card, then is pulled to the winner and fades into their seat.
        public static let gatherSeconds = 0.26
        public static let takeSeconds = 0.44
        /// Total time from the start of a trick's collection to the moment it has gone.
        public static var collectSeconds: Double { gatherSeconds + takeSeconds }
        /// The deal at the start of a hand: two rounds of three to each seat, a packet every `dealPacketGap`, each card
        /// `dealCardSeconds` in the air, starting once the riffle has finished.
        public static let dealStart = 0.5
        public static let dealPacketGap = 0.16
        public static let dealCardGap = 0.035
        public static let dealCardSeconds = 0.42
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
            case .tweed: Color(red: 0.46, green: 0.35, blue: 0.24)
            case .oxford: Color(red: 0.24, green: 0.34, blue: 0.52)
            case .burgundy: Color(red: 0.46, green: 0.14, blue: 0.20)
            }
        }
        /// Hats and glasses frames.
        public static let accessory = Color(red: 0.20, green: 0.20, blue: 0.22)
        public static let disc = Color(red: 0.10, green: 0.24, blue: 0.20)
        /// The flower hat.
        public static let blossom = Color(red: 0.93, green: 0.55, blue: 0.62)
        /// The shirt showing at a scholar's neck: the tweed jacket's and cardigan's V, the oxford's collar (D92).
        public static let collar = Color(red: 0.94, green: 0.91, blue: 0.84)
        /// The mortarboard's tassel: brick red, since gold keeps its table meanings (D33).
        public static let tassel = Color(red: 0.74, green: 0.26, blue: 0.28)
        /// A face that pops out of its disc (N49) is drawn this much larger and raised this fraction of its size.
        public static let popScale = 1.2
        public static let popRise = 0.26
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
