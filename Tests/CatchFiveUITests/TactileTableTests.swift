import CatchFive
@testable import CatchFiveUI
import Foundation
import SwiftUI
import Testing

// D97: the tactile table. Motion is view state derived from the match; these tests hold the planner, the flights and
// the landing rules to that, and pin the new card faces and the field.

private func orderedDeck() -> [Card] { Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } } }

/// A match bid and named by seat 0, ready for the first lead.
private func matchReadyToPlay() throws -> Match {
    var match = try Match(deck: orderedDeck(), dealer: 3)
    try match.bid(seat: 0, amount: 9)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    return match
}

private func playNext(_ match: inout Match) throws {
    let seat = try #require(match.hand.nextSeat)
    try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
}

@Test func onePlayForwardIsAFlightAndAnythingElseIsAReset() throws {
    var match = try Match(deck: orderedDeck(), dealer: 3)
    var seen = MotionSnapshot(match: match)
    // A bid moves no card.
    try match.bid(seat: 0, amount: 9)
    #expect(MotionSnapshot.change(from: seen, to: MotionSnapshot(match: match)) == .quiet)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    seen = MotionSnapshot(match: match)
    // A play is one card onto the field, numbered from the hand's first play.
    try playNext(&match)
    let first = MotionSnapshot(match: match)
    guard case let .played(play, index) = MotionSnapshot.change(from: seen, to: first) else {
        Issue.record("a play should fly"); return
    }
    #expect(play.seat == 0 && index == 0)
    // The fourth card completes the trick and is still one play forward.
    try playNext(&match); try playNext(&match)
    let third = MotionSnapshot(match: match)
    try playNext(&match)
    guard case let .played(_, fourth) = MotionSnapshot.change(from: third, to: MotionSnapshot(match: match)) else {
        Issue.record("the trick's last card should fly"); return
    }
    #expect(fourth == 3 && match.hand.completedTricks.count == 1)
    // Undo is not a step forward: everything is put where it is.
    let rewound = try match.rewound(toActionCount: match.actionCount - 2)
    #expect(MotionSnapshot.change(from: MotionSnapshot(match: match), to: MotionSnapshot(match: rewound)) == .reset)
    // A new game is a reset too.
    let fresh = try Match(deck: orderedDeck(), dealer: 1)
    #expect(MotionSnapshot.change(from: MotionSnapshot(match: match), to: MotionSnapshot(match: fresh)) == .reset)
}

@MainActor @Test func theNextHandIsDealt() throws {
    var match = try matchReadyToPlay()
    while match.hand.phase != .finished { try playNext(&match) }
    let finished = MotionSnapshot(match: match)
    try match.startNextHand(deck: GameModel.deck())
    #expect(MotionSnapshot.change(from: finished, to: MotionSnapshot(match: match)) == .dealt)
}

@Test func aFlightRunsFromItsStartThroughEachLegAndStopsAtTheEnd() {
    let start = CardPose(centre: CGPoint(x: 0, y: 0), rotation: -10, scale: 0.4)
    let middle = CardPose(centre: CGPoint(x: 100, y: 0), scale: 1)
    let end = CardPose(centre: CGPoint(x: 100, y: 200), scale: 0.3, opacity: 0)
    let flight = Flight(id: 1, card: nil, width: 60, from: start,
                        legs: [.init(to: middle, seconds: 0.4, ease: .out, arc: 20), .init(to: end, seconds: 0.2, ease: .linear)],
                        delay: 0.5)
    #expect(abs(flight.duration - 0.6) < 1e-9 && abs(flight.lands - 1.1) < 1e-9)
    #expect(flight.pose(at: 0) == start)
    #expect(flight.pose(at: 0.4) == middle)
    #expect(flight.pose(at: 0.6) == end && flight.pose(at: 5) == end)
    // An arc bows the path to one side at its middle, and nowhere at its ends.
    #expect(abs(flight.pose(at: 0.2).centre.y) > 1)
    // Easing never overshoots.
    for ease in [Flight.Ease.out, .into, .inOut, .linear] {
        #expect(Flight.eased(0, ease) == 0 && Flight.eased(1, ease) == 1)
        #expect((0...20).map { Flight.eased(Double($0) / 20, ease) }.allSatisfy { (0...1).contains($0) })
    }
}

@Test func aComputersCardFliesFromItsFaceToItsRestingPlace() throws {
    var geometry = TableGeometry()
    geometry.pileCentre = CGPoint(x: 200, y: 400)
    geometry.seats = [0: CGPoint(x: 200, y: 760), 1: CGPoint(x: 50, y: 400), 2: CGPoint(x: 200, y: 160), 3: CGPoint(x: 350, y: 400)]
    let play = Play(seat: 1, card: Card(.hearts, .five))
    let flight = try #require(FlightPlan.play(play, index: 5, place: 1, handNumber: 3, geometry: geometry))
    // It starts small at the player's face and lands exactly where the field draws the card.
    #expect(flight.from.centre == geometry.seats[1] && flight.from.scale < 0.5)
    let rest = FlightPlan.rest(place: 1, card: play.card, handNumber: 3, trickIndex: 1, pileCentre: CGPoint(x: 200, y: 400))
    #expect(flight.pose(at: flight.duration) == rest)
    #expect(flight.arrival == .field(playIndex: 5))
    // Where the field draws it: the seat's nudge plus the card's own toss for that trick.
    let toss = CardToss.pose(for: play.card, hand: 3, trick: 1)
    #expect(rest.centre.x == 200 - Theme.Table.sideNudge + toss.offset.width && rest.rotation == toss.rotation)
    // Your own card leaves from wherever your finger let it go.
    let launch = CardPose(centre: CGPoint(x: 210, y: 700), rotation: 4, scale: 1)
    let yours = try #require(FlightPlan.play(Play(seat: 0, card: Card(.clubs, .ace)), index: 6, place: 0, handNumber: 3,
                                             geometry: geometry, launch: launch))
    #expect(yours.from == launch)
    // With no measurements yet there is nothing to fly; the table shows the card where it lands.
    #expect(FlightPlan.play(play, index: 5, place: 1, handNumber: 3, geometry: TableGeometry()) == nil)
}

@Test func aFinishedTrickGathersOnTheWinnerAndIsTakenToThem() throws {
    var match = try matchReadyToPlay()
    for _ in 0..<4 { try playNext(&match) }
    let trick = try #require(match.hand.completedTricks.first)
    var geometry = TableGeometry()
    geometry.pileCentre = CGPoint(x: 200, y: 400)
    geometry.seats = [0: CGPoint(x: 200, y: 760), 1: CGPoint(x: 50, y: 400), 2: CGPoint(x: 200, y: 160), 3: CGPoint(x: 350, y: 400)]
    let flights = FlightPlan.collect(trick, trickIndex: 0, handNumber: 1, places: { $0 }, geometry: geometry)
    #expect(flights.count == 4)
    let target = try #require(geometry.seats[trick.winner])
    for flight in flights {
        let end = flight.pose(at: flight.duration)
        #expect(end.centre == target && end.opacity == 0 && end.scale < 0.5)
        // The first leg gathers every card onto the winner's spot on the field.
        let winning = FlightPlan.rest(place: trick.winner, card: trick.plays.first { $0.seat == trick.winner }!.card,
                                      handNumber: 1, trickIndex: 0, pileCentre: CGPoint(x: 200, y: 400))
        let gathered = flight.pose(at: Theme.Motion.gatherSeconds)
        #expect(hypot(gathered.centre.x - winning.centre.x, gathered.centre.y - winning.centre.y) < 6)
    }
    // The winning card rides on top, and the whole trick takes `collectSeconds`.
    let top = try #require(flights.max { $0.layer < $1.layer })
    #expect(top.card == trick.plays.first { $0.seat == trick.winner }?.card)
    #expect(flights.allSatisfy { abs($0.duration - Theme.Motion.collectSeconds) < 1e-9 })
}

@Test func theDealGoesRoundTheTableFromTheDealersLeftTwoRoundsOfThree() throws {
    var geometry = TableGeometry()
    geometry.deck = CGPoint(x: 60, y: 300)
    geometry.seats = [1: CGPoint(x: 50, y: 400), 2: CGPoint(x: 200, y: 160), 3: CGPoint(x: 350, y: 400)]
    geometry.hand = HandFanView.Geometry(frame: CGRect(x: 16, y: 650, width: 361, height: 130), baseWidth: 64, scaledWidth: 75, available: 345)
    let cards = Array(orderedDeck().prefix(6))
    // The dealer sits across (place 2), so the first packet goes to the right (place 3).
    let flights = FlightPlan.deal(dealerPlace: 2, yourCards: cards, geometry: geometry)
    #expect(flights.count == 24)
    let first = try #require(flights.min { $0.delay < $1.delay })
    #expect(first.pose(at: first.duration).centre.x > 300)
    // Your six arrive in your hand face down and edge-on, one per card, in their own places; the rest go to the seats.
    let yours = flights.filter { if case .hand = $0.arrival { true } else { false } }
    #expect(yours.count == 6 && Set(yours.map(\.arrival)) == Set(cards.map { Flight.Arrival.hand($0) }))
    #expect(yours.allSatisfy { $0.card == nil && $0.pose(at: $0.duration).turn == 90 })
    let landed = yours.map { $0.pose(at: $0.duration).centre.x }
    #expect(Set(landed).count == 6)
    // Everyone else's cards disappear into their seat.
    #expect(flights.filter { $0.arrival == .none }.allSatisfy { $0.pose(at: $0.duration).opacity == 0 })
    // It all happens in a couple of seconds; the first bid waits for the last card to land.
    let lands = flights.map(\.lands).max() ?? 0
    #expect(lands > 1 && lands < 2.5)
}

@Test func landingShowsWhatAFlightCarriedAndAResetPutsEverythingBack() throws {
    var match = try matchReadyToPlay()
    var motion = TableMotion(match: match)
    #expect(motion.landedPlays == 0 && motion.isInHand(Card(.clubs, .ace), handNumber: match.handNumber))
    try playNext(&match)
    let flights = motion.launch([Flight(id: 0, card: nil, width: 60, from: CardPose(centre: .zero),
                                        legs: [.init(to: CardPose(centre: .zero), seconds: 0.1)], arrival: .field(playIndex: 0))])
    // In the air: not yet on the field.
    #expect(!motion.hasLanded(playIndex: 0) && motion.flights.count == 1)
    motion.land(try #require(flights.first), handNumber: match.handNumber)
    #expect(motion.hasLanded(playIndex: 0) && motion.flights.isEmpty)
    // A reset lands everything at once and makes earlier landings stale.
    let epoch = motion.epoch
    _ = motion.launch(flights)
    for _ in 0..<2 { try playNext(&match) }
    motion.reset(to: match)
    #expect(motion.flights.isEmpty && motion.landedPlays == 3 && motion.epoch == epoch + 1)
}

@MainActor @Test func aDealtHandIsHiddenUntilEachCardLands() throws {
    var match = try matchReadyToPlay()
    while match.hand.phase != .finished { try playNext(&match) }
    var motion = TableMotion(match: match)
    try match.startNextHand(deck: GameModel.deck())
    let cards = Array(match.hand.hands[0])
    // The new hand is not in the player's hand until it is dealt.
    #expect(cards.allSatisfy { !motion.isInHand($0, handNumber: match.handNumber) })
    motion.dealStarted = match.handNumber
    let flights = motion.launch(cards.map { Flight(id: 0, card: nil, width: 60, from: CardPose(centre: .zero),
                                                   legs: [.init(to: CardPose(centre: .zero), seconds: 0.1)], arrival: .hand($0)) })
    motion.land(flights[0], handNumber: match.handNumber)
    #expect(motion.isInHand(cards[0], handNumber: match.handNumber) && !motion.isInHand(cards[1], handNumber: match.handNumber))
    for flight in flights.dropFirst() { motion.land(flight, handNumber: match.handNumber) }
    #expect(motion.dealtHand == match.handNumber && motion.dealtCards.isEmpty)
    // A fresh match still behind its draw for dealer waits for its deal too.
    let fresh = try Match(deck: orderedDeck(), dealer: 1)
    #expect(!TableMotion(match: fresh, dealPending: true).isInHand(fresh.hand.hands[0][0], handNumber: fresh.handNumber))
}

@Test func theLastTrickIsTakenBeforeTheResultComesUp() throws {
    var match = try matchReadyToPlay()
    while match.hand.phase != .finished { try playNext(&match) }
    let count = match.hand.completedTricks.count
    // The finished hand still holds its last trick for its winner, once.
    #expect(TableScheduler.plan(hand: match.hand, collapsedTricks: count - 1).hold)
    #expect(!TableScheduler.plan(hand: match.hand, collapsedTricks: count).hold)
}

@Test func cardsArePokerSizedWithRealPipLayouts() {
    // D97: a poker card's 2.5 × 3.5 inches.
    #expect(abs(Theme.Card.ratio - 1.4) < 1e-9)
    let numbers: [Rank] = [.two, .three, .four, .five, .six, .seven, .eight, .nine, .ten]
    for rank in numbers {
        let pips = CardFace.pipLayout(rank)
        #expect(pips.count == rank.rawValue, "\(rank) has \(pips.count) pips")
        #expect(pips.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
        // Laid out as a deck prints them: turned end for end, the pips land on one another, except the seven's odd
        // pip, which sits above the middle.
        let key: (Double, Double) -> String = { String(format: "%.4f,%.4f", $0, $1) }
        let turned = Set(pips.map { key(1 - $0.x, 1 - $0.y) }), upright = Set(pips.map { key($0.x, $0.y) })
        #expect(rank == .seven ? turned.subtracting(upright).count == 1 : turned == upright)
    }
    for rank in [Rank.jack, .queen, .king, .ace] { #expect(CardFace.pipLayout(rank).isEmpty) }
    #expect(CardFace.isCourt(.queen) && !CardFace.isCourt(.ace))
}

@Test func theFieldSitsBetweenTheSeatsAndReadsUnderTheCards() {
    // Cream cards on the walnut read at well over 7:1; chalked calls read on the walnut and on the oak.
    #expect(Carving.contrast(.ivory, on: Theme.Field.walnut) >= 7)
    #expect(Carving.contrast(.ivory.opacity(0.94), on: Theme.Field.walnut) >= 4.5)
    #expect(Carving.contrast(.ivory.opacity(0.94), on: Theme.Wood.base) >= 3)
    // The field fits between the side tiles, reaching just under each.
    let edges = TableSurface.FieldEdges(top: 130, bottom: 520, left: 100, right: 290)
    let rect = edges.rect
    #expect(rect?.minX == 100 - Theme.Field.sideTuck && rect?.maxX == 290 + Theme.Field.sideTuck)
    #expect(TableSurface.FieldEdges().rect == nil)
    // The lamp sits toward the seat to act and nowhere when nobody is.
    #expect(TableField.lampOffset(place: 1, size: CGSize(width: 200, height: 400)).width < 0)
    #expect(TableField.lampOffset(place: 0, size: CGSize(width: 200, height: 400)).height > 0)
    #expect(TableField.lampOffset(place: nil, size: CGSize(width: 200, height: 400)) == .zero)
}

@Test func theSidesWearTheirOwnRim() {
    // Your team's faces are rimmed light, the opponents' oxblood, from whoever holds the phone.
    #expect(SeatView.rim(seat: 0, ourTeam: 0) == Theme.Team.ourRim && SeatView.rim(seat: 2, ourTeam: 0) == Theme.Team.ourRim)
    #expect(SeatView.rim(seat: 1, ourTeam: 0) == Theme.Team.theirRim && SeatView.rim(seat: 3, ourTeam: 0) == Theme.Team.theirRim)
    #expect(SeatView.rim(seat: 1, ourTeam: 1) == Theme.Team.ourRim)
    #expect(Theme.Team.ourRim != Theme.Team.theirRim)
}

@Test func aPickedCardSaysHowToPlayIt() {
    #expect(TableSurface.selectedCaption(Card(.hearts, .queen)) == "Tap your spot on the table to play the Q♥")
    // Dragging a card most of a card's height up plays it; a legal card stands up, an illegal one sinks.
    #expect(Theme.Card.dragToPlay >= 44 && Theme.Card.liftSelected > Theme.Card.liftPlayable && Theme.Card.sinkDimmed > 0)
}

@Test func theHandsLayoutPlacesEveryCardOfAFlatOrFannedRow() throws {
    let geometry = HandFanView.Geometry(frame: CGRect(x: 0, y: 600, width: 360, height: 130), baseWidth: 64, scaledWidth: 75, available: 344)
    // Flat, as in the auction: level and evenly spaced about the middle.
    let flat = (0..<6).compactMap { geometry.pose(slot: $0, count: 6, flat: true) }
    #expect(flat.count == 6 && Set(flat.map(\.centre.y)).count == 1)
    #expect(abs((flat[0].centre.x + flat[5].centre.x) / 2 - 180) < 1e-6)
    // Fanned: the outer cards turn out to ±8° and sit a little lower than the middle ones.
    let fan = (0..<6).compactMap { geometry.pose(slot: $0, count: 6, flat: false) }
    #expect(abs(fan[0].rotation + Theme.Card.fanRotationDegrees) < 1e-9 && abs(fan[5].rotation - Theme.Card.fanRotationDegrees) < 1e-9)
    #expect(fan[0].centre.y > fan[2].centre.y)
    // Lifting raises the card; nothing is placed before the hand has been measured.
    #expect(try #require(geometry.pose(slot: 2, count: 6, flat: false, lift: 30)).centre.y < fan[2].centre.y)
    #expect(HandFanView.Geometry(frame: .zero, baseWidth: 64, scaledWidth: 75, available: 0).pose(slot: 0, count: 6, flat: true) == nil)
}

@Test func theTrickGrowsWithItsCards() {
    // The top and bottom of the trick grow with the cards, so cards drawn larger keep the same share clear of the
    // side ones (D112: about half a card, where it was a whole one).
    for scale in [1.0, 1.18, 1.27] {
        let height = Theme.Card.pileWidth * Theme.Card.ratio * scale
        #expect(abs(TableSurface.pileOffset(for: 2, scale: scale).height) >= height * Theme.Table.trickRise - 1e-9)
        let side = Double(abs(TableSurface.pileOffset(for: 1, scale: scale).width))
        #expect(side * 2 >= Theme.Card.pileWidth * scale + 2 * Theme.Table.tossDrift)
    }
}

@MainActor @Test func aNewHandStartsWithNothingOfItOnTheField() throws {
    // Review finding: the count of landed plays carried over from the last hand, so the next hand's cards were drawn on
    // the field while still in the air.
    var match = try matchReadyToPlay()
    while match.hand.phase != .finished { try playNext(&match) }
    var motion = TableMotion(match: match)
    #expect(motion.landedPlays == 24)
    let before = MotionSnapshot(match: match)
    try match.startNextHand(deck: GameModel.deck())
    let change = MotionSnapshot.change(from: before, to: MotionSnapshot(match: match))
    motion.apply(change, to: match)
    #expect(change == .dealt && motion.landedPlays == 0 && !motion.hasLanded(playIndex: 0))
}

@MainActor @Test func aDealThatCanNoLongerRunIsSkippedSoTheHandShows() throws {
    // Review finding: a bid made before the deal began left the deal unstarted and the hand hidden all hand.
    var match = try matchReadyToPlay()
    while match.hand.phase != .finished { try playNext(&match) }
    var motion = TableMotion(match: match)
    try match.startNextHand(deck: GameModel.deck())
    let number = match.handNumber
    #expect(motion.dealStep(for: match.hand, handNumber: number, canAnimate: true) == .animate)
    // Under Reduce Motion or the curtain it is skipped from the start.
    #expect(motion.dealStep(for: match.hand, handNumber: number, canAnimate: false) == .skip)
    // Once someone has called, it is too late to deal: skip it, and every card is in the hand.
    let seat = try #require(match.hand.nextSeat)
    try match.bid(seat: seat, amount: nil)
    #expect(motion.dealStep(for: match.hand, handNumber: number, canAnimate: true) == .skip)
    motion.skipDeal(handNumber: number)
    #expect(match.hand.hands[0].allSatisfy { motion.isInHand($0, handNumber: number) })
    #expect(motion.dealStep(for: match.hand, handNumber: number, canAnimate: true) == .none)
}

@Test func theTableSpeaksOnlyToYouButVoiceOverHearsEverything() {
    // D98: the white lines announcing each hand and play are gone; the status line's VoiceOver words keep them.
    #expect(TableSurface.spokenStatus(prompt: "Your turn", actor: nil, notice: nil) == "Your turn")
    #expect(TableSurface.spokenStatus(prompt: nil, actor: "Monica is bidding", notice: nil) == "Monica is bidding")
    #expect(TableSurface.spokenStatus(prompt: nil, actor: nil, notice: "Discarded: You 3 · Marcus 4") == "Discarded: You 3 · Marcus 4")
    #expect(TableSurface.spokenStatus(prompt: "Your turn", actor: "ignored", notice: "Discarded: You none") == "Your turn. Discarded: You none")
}

@Test func theScorePadLiesBottomLeftOnlyWhileCardsArePlayed() {
    // D100: the pad is back at its first size, in the bottom-left corner by the hand. The auction's buttons and the
    // reviewed trick's way back need that corner, and the result card carries both totals.
    #expect(Scorecard.liesOnTable(phase: .playing, reviewing: false))
    #expect(!Scorecard.liesOnTable(phase: .playing, reviewing: true))
    #expect(!Scorecard.liesOnTable(phase: .bidding, reviewing: false))
    #expect(!Scorecard.liesOnTable(phase: .choosingTrump, reviewing: false))
    #expect(!Scorecard.liesOnTable(phase: .finished, reviewing: false))
    // Its first size: the corner's width on a wide phone, three ruled lines under the heading.
    #expect(TableLayout.cornerWidth(available: 402 - 32) == Theme.Table.cornerWidth)
    #expect(Theme.Table.scorecardLines == 3)
}

@Test func theRulesBookIsPortraitAndKeepsItsTrailingCorner() {
    #expect(Theme.Table.rulesBookHeight > Theme.Table.rulesBookWidth)
    for width in [308.0, 363, 390] {
        let frame = TableLayout.bookFrame(available: width)
        #expect(frame.maxX <= width && frame.minX >= 44)
        #expect(frame.maxY + 12 <= Theme.Table.topRowHeight + TableLayout.topCornerClearance)
    }
}

@MainActor @Test func theAuctionTakesNoTapsUntilYourDealtHandHasLanded() throws {
    let fresh = try Match(deck: orderedDeck(), dealer: 1)
    let cards = Array(fresh.hand.hands[0])
    var motion = TableMotion(match: fresh, dealPending: true)
    #expect(!TableSurface.handLanded(cards, motion: motion, handNumber: fresh.handNumber))
    motion.skipDeal(handNumber: fresh.handNumber)
    #expect(TableSurface.handLanded(cards, motion: motion, handNumber: fresh.handNumber))
    // Reduce Motion passes no motion: nothing is dealt in flight, so the hand is already there.
    #expect(TableSurface.handLanded(cards, motion: nil, handNumber: fresh.handNumber))
}

@Test func aPlayedCardShowsItsPlayerOnTheirSideOfTheTable() {
    // The player of a card looks over its edge from where they sit (D145); your own card needs no face.
    #expect(TableSurface.peek(for: 0) == nil)
    #expect((TableSurface.peek(for: 1)?.out.width ?? 0) < 0)   // the left seat peeks from the left
    #expect((TableSurface.peek(for: 3)?.out.width ?? 0) > 0)   // the right seat from the right
    #expect(TableSurface.peek(for: 2)?.out.width == 0)         // the partner from straight above
    for place in 1...3 { #expect((TableSurface.peek(for: place)?.out.height ?? 0) < 0) }
}

@Test func aPlayerCardReadsPlayStyleOffTheCounts() {
    // D151: the card's line about how someone plays comes from the match, not from a made-up personality.
    func style(hands: Int, won: Int, made: Int, average: Double?) -> String {
        PlayerSheet(hands: hands, bidsWon: won, made: made, set: won - made, averageBid: average, tricksThisHand: 0, sideScore: 0).style
    }
    #expect(style(hands: 0, won: 0, made: 0, average: nil) == "Too early to tell")
    #expect(style(hands: 4, won: 0, made: 0, average: nil) == "Lets others do the bidding")
    #expect(style(hands: 4, won: 3, made: 1, average: 5) == "Bites off more than they can chew")
    #expect(style(hands: 4, won: 1, made: 1, average: 5) == "Bold bidder")
    #expect(style(hands: 4, won: 2, made: 2, average: 3) == "Likes to run the table")
    #expect(style(hands: 6, won: 1, made: 1, average: 3) == "Steady hand")
}

@Test func theContractCardReadsTheAuctionBack() throws {
    // D157: who took it, each seat's last call in the order they spoke, the score from our side.
    var auction = try Auction(dealer: 0)
    try auction.act(seat: 1, bid: 2)
    try auction.act(seat: 2, bid: nil)
    try auction.act(seat: 3, bid: 4)
    try auction.act(seat: 0, bid: nil)
    let summary = try #require(ContractCard.Summary(auction: auction, trump: .hearts, names: ["Ann", "Bo", "Cy", "Di"], scores: [7, 12], ourTeam: 1))
    #expect(summary.headline == "Di took the bid at 4")
    #expect(summary.calls.map(\.name) == ["Bo", "Cy", "Di", "Ann"])
    #expect(summary.calls.map(\.words) == ["2", "Pass", "4", "Pass"])
    #expect(summary.calls.map(\.won) == [false, false, true, false])
    #expect(summary.us == 12 && summary.them == 7)
    #expect(SpeechBubble.tail(toward: CGSize(width: -10, height: -5)) == .leading)
    #expect(SpeechBubble.tail(toward: CGSize(width: 0, height: 20)) == .bottom)
}
