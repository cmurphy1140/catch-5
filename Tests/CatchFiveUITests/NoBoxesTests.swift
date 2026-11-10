import CatchFive
@testable import CatchFiveUI
import Foundation
import SwiftUI
import Testing

@MainActor @Test func carvingsReadOnTheWood() {
    // D94: carved words and suits are dark recesses in the wood, at least 3:1 against it (large-text contrast),
    // and red suits keep a red of their own so hearts and diamonds still read as red.
    #expect(Carving.contrast(Carving.ink, on: Theme.Wood.base) >= 3)
    #expect(Carving.contrast(Carving.ink(for: .hearts), on: Theme.Wood.base) >= 3)
    #expect(Carving.ink(for: .spades) == Carving.ink && Carving.ink(for: .clubs) == Carving.ink)
    let red = Carving.ink(for: .hearts)
    #expect(red == Carving.ink(for: .diamonds))
    #expect(red != Carving.ink)
    // The lit lower edge is lighter than the wood it sits in, so the recess reads as cut, not printed.
    #expect(Carving.luminance(Carving.litEdge) > Carving.luminance(Theme.Wood.base))
}

@Test func nothingAPlayerMustReadIsSmallerThanFifteenPoints() {
    // D94: no more small lettering on the table.
    for size in [Theme.Table.carvedNameSize, Theme.Table.trumpWordSize, Theme.Table.bidEyebrowSize, Theme.Table.dealerButtonLetterSize] {
        #expect(size >= 15)
    }
}

@MainActor @Test func trumpIsCarvedBesideTheBiddersNameAndBesideTheBid() throws {
    // D94: once trump is named, the bidder's seat carries it by the name, and the bid corner beside the bid.
    #expect(SeatView.carvedTrump(seat: 2, bidder: 2, trump: .hearts) == .hearts)
    #expect(SeatView.carvedTrump(seat: 1, bidder: 2, trump: .hearts) == nil)
    #expect(SeatView.carvedTrump(seat: 2, bidder: 2, trump: nil) == nil)
    #expect(SeatView.carvedTrump(seat: 2, bidder: nil, trump: .spades) == nil)
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    model.send(.chooseTrump(.clubs))
    #expect(try #require(ContractPlaque.contract(in: model)).trump == .clubs)
}

@Test func theDealerButtonRestsInFrontOfTheDealersSeat() {
    // D94: a round puck, "D" engraved, in front of whoever deals: under the hand for you, under the face at the
    // sides, beside the partner's tile across the top.
    #expect(DealerMark.engraving == "D")
    #expect(DealerMark.placement(forPlace: 0) == .besideYourName)
    #expect(DealerMark.placement(forPlace: 1) == .underFace)
    #expect(DealerMark.placement(forPlace: 2) == .besideTile)
    #expect(DealerMark.placement(forPlace: 3) == .underFace)
    // Only the left seat, and only while the pad lies under it, wears the button on its face (D112).
    #expect(SeatView.puckRidesTheFace(place: 1, phase: .playing))
    #expect(!SeatView.puckRidesTheFace(place: 3, phase: .playing) && !SeatView.puckRidesTheFace(place: 1, phase: .bidding))
    #expect(Theme.Table.dealerButtonSize >= 44)
}

@Test func theCarvedNameStillRenamesItsSeat() {
    // D93 kept under D94: the carved name is the rename button, a full thumb tall.
    #expect(NameTag.hitHeight >= 44)
    #expect(NameTag.renameHint == "Rename this seat")
}

@Test func theScorePadLiesOnTheTableAtASlightTurn() {
    // D94: paper lying on the wood, turned a little, with no frame drawn round it.
    #expect(abs(Scorecard.tiltDegrees) >= 1 && abs(Scorecard.tiltDegrees) <= 4)
    #expect(Scorecard.shadowRadius > 0)
}

@Test func theRulesOpenLikeABook() {
    // D94: the page swings onto the screen about its left edge, edge-on at the start and flat when open, in half a second.
    #expect(BookFold.angle(progress: 0) == 90)
    #expect(BookFold.angle(progress: 1) == 0)
    #expect(BookFold.angle(progress: 0.5) == 45)
    #expect(BookFold.seconds == 0.5)
    // The `table-rules-fold` screenshot stage holds the fold halfway.
    #expect(BookFold.heldProgress(stage: "table-rules-fold") == 0.5)
    #expect(BookFold.heldProgress(stage: "table") == nil)
}
