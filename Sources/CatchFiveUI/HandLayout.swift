import Foundation

/// How the human's hand is laid out for a given width, decided from measurements rather than hoped for.
/// The one invariant: every card exposes at least `Theme.Card.minimumTouchStrip` to a thumb. A fan that
/// cannot promise that gives way to two rows, which can.
enum HandLayout {
    enum Arrangement: Equatable {
        /// One overlapped row; `strip` is the exposed width of every card but the last.
        case fan(strip: Double)
        /// Two rows of `perRow` cards, each row with its own `strip`.
        case rows(perRow: Int, strip: Double)
    }

    /// The widest strip a row of `count` cards can have inside `available`, capped at the fan's own overlap.
    private static func strip(count: Int, cardWidth: Double, available: Double) -> Double {
        let ideal = Theme.Card.touchStrip(width: cardWidth)
        guard count > 1 else { return ideal }
        return min(ideal, (available - cardWidth) / Double(count - 1))
    }

    static func arrange(count: Int, cardWidth: Double, available: Double,
                        minimumStrip: Double = Theme.Card.minimumTouchStrip) -> Arrangement {
        let fan = strip(count: count, cardWidth: cardWidth, available: available)
        if count <= 1 || fan >= minimumStrip { return .fan(strip: fan) }
        let perRow = Int((Double(count) / 2).rounded(.up))
        return .rows(perRow: perRow, strip: strip(count: perRow, cardWidth: cardWidth, available: available))
    }

    /// Vertical room the hand needs: one card plus the fan's drop, or two cards and a gap.
    /// The air between cards when the hand lies flat during the auction (B01).
    static let baselineGap = 6.0

    /// The auction's flat row: every card on one baseline, evenly spaced, overlapping evenly only when the
    /// row would not otherwise fit (B01).
    static func baselineStrip(count: Int, cardWidth: Double, available: Double) -> Double {
        guard count > 1 else { return cardWidth + baselineGap }
        return min(cardWidth + baselineGap, (available - cardWidth) / Double(count - 1))
    }

    static func height(of arrangement: Arrangement, cardWidth: Double, flat: Bool = false) -> Double {
        let card = cardWidth * Theme.Card.ratio
        switch arrangement {
        // A hand lying flat for the auction needs no room for the fan's lift and arc (D97).
        case .fan where flat: return card + 4
        case .fan: return card + 16 + Theme.Card.fanDrop
        case .rows: return 2 * card + rowGap + 16
        }
    }

    static let rowGap = 8.0
}

/// The seat row: two side tiles and the pile between them share the table's width. The tiles give
/// way first, down to a floor that still fits a portrait and a short name.
enum TableLayout {
    /// The table's coordinate space, shared by the dealer's deck and the hand so a deal can fly between them.
    static let space = "table"
    /// A pile card nudged toward either side seat, plus 4 pt of air on each side.
    static var pileReservation: Double { pileReservation(scale: 1) }
    static func pileReservation(scale: Double) -> Double {
        let radians = Theme.Table.tossRotationDegrees * .pi / 180
        let card = Theme.Card.pileWidth * (cos(radians) + Theme.Card.ratio * sin(radians))
        return (card + 2 * Theme.Table.sideNudge) * scale + 2 * Theme.Table.tossDrift
    }
    /// How far the partner's card sits above the pile's centre, and yours below it (D112).
    static func pileRise(scale: Double) -> Double { Theme.Table.partnerNudge * scale + Theme.Table.tossDrift }
    /// The pile's height: a card nudged up for the partner and one nudged down for you, with room for their toss.
    static var pileHeight: Double { pileHeight(scale: 1) }
    static func pileHeight(scale: Double) -> Double {
        let radians = Theme.Table.tossRotationDegrees * .pi / 180
        let card = Theme.Card.pileWidth * (Theme.Card.ratio * cos(radians) + sin(radians)) * scale
        return card + 2 * pileRise(scale: scale) + 2 * Theme.Table.tossDrift
    }
    /// The largest scale whose pile is no taller than `room`, held between `minimumPileScale` and `preferred` (D112).
    static func pileScale(room: Double, preferred: Double) -> Double {
        let fixed = 4 * Theme.Table.tossDrift
        return min(preferred, max(Theme.Table.minimumPileScale, (room - fixed) / (pileHeight(scale: 1) - fixed)))
    }
    /// The score pad on the table: four fifths of a corner, so it lies under the side seat's name, not over it (D112).
    static let padScale = 0.8
    static func padWidth(available: Double) -> Double { cornerWidth(available: available) * padScale }
    /// Support on the top row: beside the rules book, clear of it and of the home arrow.
    static func supportFrame(available: Double) -> CGRect {
        let width = 112.0
        return CGRect(x: bookFrame(available: available).minX - 6 - width, y: (Theme.Table.topRowHeight - 44) / 2, width: width, height: 44)
    }
    /// The spacer between a tile and the pile.
    static let seatGap = 2.0
    static let minimumSeatWidth = 78.0

    /// Each top corner's width: up to `Theme.Table.cornerWidth`, and never so wide that the two corners and the
    /// partner's tile overrun the row (N51).
    static func cornerWidth(available: Double) -> Double {
        min(Theme.Table.cornerWidth, (available - Theme.Table.seatTileWidth) / 2 - 2)
    }

    static func sideSeatWidth(available: Double) -> Double {
        let room = (available - pileReservation(scale: pileScale(available: available, preferred: 1.35)) - 2 * seatGap) / 2
        return max(minimumSeatWidth, min(Theme.Table.seatTileWidth, room))
    }
}

extension HandLayout {
    static func fittedCardWidth(preferred: Double, available: Double) -> Double {
        min(preferred, max(Theme.Card.minimumTouchStrip, available - 5 * Theme.Card.minimumTouchStrip))
    }
}

extension TableLayout {
    static func pileScale(available: Double, preferred: Double = 1) -> Double {
        let room = available - 2 * minimumSeatWidth - 2 * seatGap - 2 * Theme.Table.tossDrift
        return min(preferred, max(0.1, room / (pileReservation - 2 * Theme.Table.tossDrift)))
    }
    static func bookFrame(available: Double) -> CGRect {
        CGRect(x: available - Theme.Table.rulesBookWidth - 8, y: 6, width: Theme.Table.rulesBookWidth, height: Theme.Table.rulesBookHeight)
    }
    static var topCornerClearance: Double { max(0, Theme.Table.rulesBookHeight + 24 - Theme.Table.topRowHeight) }
}
