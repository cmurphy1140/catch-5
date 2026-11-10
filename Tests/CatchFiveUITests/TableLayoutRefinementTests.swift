import Foundation
import Testing
@testable import CatchFiveUI

@Test func tablePortraitBookAndLargerNamesUseReservedGeometry() {
    let book = CGSize(width: Theme.Table.rulesBookWidth, height: Theme.Table.rulesBookHeight)
    #expect(book.height / book.width >= 1.4 && book.height / book.width <= 1.5)
    #expect(Theme.Table.topRowHeight + TableLayout.topCornerClearance >= book.height + 12)
    #expect(Theme.Table.carvedNameSize >= 27)
}

@Test func tableCardsUseMoreOfTheAvailableWidth() {
    #expect(Theme.Card.handWidth >= 78)
    #expect(Theme.Card.handWidthWide >= 84)
    #expect(Theme.Card.pileWidth >= 82)
}

@Test func tableAdaptiveCardsAndControlsFitCompactAndTargetWidths() {
    for screen in [320.0, 375, 393, 402] {
        let available = screen - 12
        let scale = TableLayout.pileScale(available: available, preferred: 1.24)
        let tile = TableLayout.sideSeatWidth(available: available)
        #expect(2 * tile + TableLayout.pileReservation(scale: scale) + 2 * TableLayout.seatGap <= available + 0.01)
        let hand = HandLayout.fittedCardWidth(preferred: 104, available: available - 16)
        #expect(hand + 5 * Theme.Card.minimumTouchStrip <= available - 16 + 0.01)
        let book = TableLayout.bookFrame(available: available)
        // Support sits on the top row between the home arrow and the book, touching neither (D112).
        let support = TableLayout.supportFrame(available: available)
        #expect(support.minX >= 44 + 4 && support.maxX + 4 <= book.minX)
        #expect(support.minY >= 0 && support.maxY <= Theme.Table.topRowHeight)
        // The book stands in from the trailing edge (D115, Murph: "make the rules book larger, and move it left").
        #expect(book.maxX >= available - 26 && book.maxX <= available - 22)
        #expect(CGRect(x: 0, y: 0, width: available, height: Theme.Table.topRowHeight + TableLayout.topCornerClearance).contains(book))
    }
}

@Test func tableThinkingAndExpandedFieldHaveTheirOwnBounds() {
    for available in [308.0, 363, 381, 390] {
        let tile = TableLayout.sideSeatWidth(available: available)
        let thinking = SeatView.thinkingFrame(width: tile)
        #expect(CGRect(x: 0, y: 0, width: tile, height: 22).contains(thinking))
        let field = TableSurface.FieldEdges(top: 160, bottom: 580, left: tile, right: available - tile, availableWidth: available).rect
        #expect(field != nil)
        #expect((field?.width ?? 0) >= available - 8)
        #expect((field?.minX ?? -1) >= 0 && (field?.maxX ?? 999) <= available)
        #expect((field?.minY ?? 0) >= 160 && (field?.maxY ?? 999) <= 580)
    }
}

@Test func theTrickShrinksToTheHeightItIsGiven() {
    // With room to spare the cards keep their preferred size; short of it they shrink to fit, down to a floor (D112).
    #expect(TableLayout.pileScale(room: 2000, preferred: 1.24) == 1.24)
    for room in [200.0, 230, 260, 300] {
        let scale = TableLayout.pileScale(room: room, preferred: 1.24)
        #expect(scale >= Theme.Table.minimumPileScale && scale <= 1.24)
        if scale > Theme.Table.minimumPileScale { #expect(TableLayout.pileHeight(scale: scale) <= room + 0.01) }
    }
    #expect(TableLayout.pileScale(room: 10, preferred: 1) == Theme.Table.minimumPileScale)
}

@Test func tableTossedCardsAndTopBookClearReservedFootprints() {
    for width in [308.0, 363, 381, 390] {
        let scale = TableLayout.pileScale(available: width, preferred: 1.24)
        let bounds = CGRect(x: -TableLayout.pileReservation(scale: scale) / 2, y: -TableLayout.pileHeight(scale: scale) / 2,
                            width: TableLayout.pileReservation(scale: scale), height: TableLayout.pileHeight(scale: scale))
        let radians = Theme.Table.tossRotationDegrees * .pi / 180
        let w = Theme.Card.pileWidth * scale * (cos(radians) + Theme.Card.ratio * sin(radians)) + 2 * Theme.Table.tossDrift
        let h = Theme.Card.pileWidth * scale * (Theme.Card.ratio * cos(radians) + sin(radians)) + 2 * Theme.Table.tossDrift
        for place in 0..<4 {
            let offset = TableSurface.pileOffset(for: place, scale: scale)
            let card = CGRect(x: offset.width - w / 2, y: offset.height - h / 2, width: w, height: h)
            #expect(bounds.insetBy(dx: -0.01, dy: -0.01).contains(card))
        }
        let book = TableLayout.bookFrame(available: width)
        let thinking = SeatView.thinkingFrame(width: Theme.Table.seatTileWidth)
            .offsetBy(dx: (width - Theme.Table.seatTileWidth) / 2, dy: Theme.Table.topRowHeight + 12)
        #expect(!book.insetBy(dx: -6, dy: -12).intersects(thinking))
        #expect(CGRect(x: 0, y: -6, width: width, height: Theme.Table.topRowHeight + TableLayout.topCornerClearance + 6)
            .contains(book.insetBy(dx: -6, dy: -6)))
    }
    let overflow = Theme.Table.portraitSize * Theme.Table.portraitHeadroom * Theme.Table.bigMomentScale
        + Theme.Table.portraitSize * (Theme.Table.bigMomentScale - 1)
        + Theme.Table.portraitSize * (Theme.Table.activePulseScale - 1) / 2
        + Theme.Table.activeRingGap + Theme.Table.activeRingWidth / 2
    #expect(SeatView.portraitTopInset >= overflow)
}
