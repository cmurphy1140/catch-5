import CatchFive
import SwiftUI

/// Where a card is drawn: its centre in the table's coordinate space, its turn on the table, its size relative to
/// the width it is drawn at, how visible it is, and its turn about its own upright axis (90 is edge-on).
struct CardPose: Equatable {
    var centre: CGPoint
    var rotation = 0.0
    var scale = 1.0
    var opacity = 1.0
    var turn = 0.0
}

/// One card in the air (D97). The flight layer draws it from `from` through each leg in turn; nothing about the match
/// waits for it. A flight that carries a card keeps that card off the field or out of the hand until it lands, so the
/// card is never drawn twice.
struct Flight: Identifiable, Equatable {
    enum Ease: Equatable { case out, into, inOut, linear }

    struct Leg: Equatable {
        var to: CardPose
        var seconds: Double
        var ease: Ease = .out
        /// How far the path bows to the side at its middle, in points; zero is a straight line.
        var arc = 0.0
    }

    /// What the flight's end means to the table: a play reaching the field, a dealt card reaching your hand, or
    /// nothing (a card going to another seat, or a trick being taken).
    enum Arrival: Hashable {
        case field(playIndex: Int)
        case hand(Card)
        case none
    }

    let id: Int
    /// The face shown in the air, or nil for a card travelling face down.
    let card: Card?
    /// The base width the card is drawn at before `CardPose.scale` (it still scales with the reader's text size).
    let width: Double
    let from: CardPose
    let legs: [Leg]
    /// Seconds before it leaves `from`; until then it is not drawn.
    var delay = 0.0
    var arrival = Arrival.none
    /// Higher draws on top.
    var layer = 0.0

    var duration: Double { legs.reduce(0) { $0 + $1.seconds } }
    /// Seconds from launch to landing.
    var lands: Double { delay + duration }

    /// The pose `elapsed` seconds after the flight leaves (the delay not counted).
    func pose(at elapsed: Double) -> CardPose {
        // At or past the end it is exactly the last stop, whatever rounding the legs' sums carry.
        guard elapsed < duration - 1e-9, let last = legs.last else { return legs.last?.to ?? from }
        var start = from
        var legStart = 0.0
        for leg in legs where leg.seconds > 0 {
            if elapsed < legStart + leg.seconds {
                return Self.mix(start, leg.to, Self.eased((max(0, elapsed) - legStart) / leg.seconds, leg.ease), arc: leg.arc)
            }
            legStart += leg.seconds
            start = leg.to
        }
        return last.to
    }

    static func eased(_ t: Double, _ ease: Ease) -> Double {
        let t = min(max(t, 0), 1)
        switch ease {
        case .linear: return t
        case .out: return 1 - pow(1 - t, 3)
        case .into: return t * t * t
        case .inOut: return t < 0.5 ? 4 * t * t * t : 1 - pow(-2 * t + 2, 3) / 2
        }
    }

    /// The pose a fraction `f` of the way from `a` to `b`, bowed sideways by `arc` at the middle.
    static func mix(_ a: CardPose, _ b: CardPose, _ f: Double, arc: Double = 0) -> CardPose {
        func lerp(_ x: Double, _ y: Double) -> Double { x + (y - x) * f }
        var centre = CGPoint(x: lerp(a.centre.x, b.centre.x), y: lerp(a.centre.y, b.centre.y))
        if arc != 0 {
            let dx = b.centre.x - a.centre.x, dy = b.centre.y - a.centre.y
            let length = max(hypot(dx, dy), 0.001)
            let bow = arc * 4 * f * (1 - f)
            centre.x += -dy / length * bow
            centre.y += dx / length * bow
        }
        return CardPose(centre: centre, rotation: lerp(a.rotation, b.rotation), scale: lerp(a.scale, b.scale),
                        opacity: lerp(a.opacity, b.opacity), turn: lerp(a.turn, b.turn))
    }
}

/// The table's animation state (D97): what is in the air and what has landed. It is view state only, derived from the
/// match after each accepted action and never written back; a reset puts every card where the match says it is.
struct TableMotion: Equatable {
    var flights: [Flight] = []
    /// Plays of this hand, counted from the first, that have reached the field. A later play is still in the air.
    var landedPlays: Int
    /// The newest hand whose cards are all in the player's hand. A newer hand is still being dealt.
    var dealtHand: Int
    /// Cards of the hand being dealt that have already reached the player's hand.
    var dealtCards: Set<Card> = []
    /// The hand whose deal has begun, so a paused and resumed table does not deal twice.
    var dealStarted = 0
    /// Changes whenever the state is reset, so a landing scheduled before the reset does nothing.
    var epoch = 0
    private var nextID = 0

    /// Everything where the match says it is: nothing in the air, every play landed, every card dealt.
    init(match: Match, dealPending: Bool = false) {
        landedPlays = MotionSnapshot(match: match).plays.count
        dealtHand = dealPending ? match.handNumber - 1 : match.handNumber
        dealStarted = dealtHand
    }

    mutating func reset(to match: Match, dealPending: Bool = false) {
        let epoch = epoch + 1
        self = TableMotion(match: match, dealPending: dealPending)
        self.epoch = epoch
    }

    mutating func launch(_ planned: [Flight]) -> [Flight] {
        let numbered = planned.map { flight -> Flight in
            nextID += 1
            return Flight(id: nextID, card: flight.card, width: flight.width, from: flight.from, legs: flight.legs,
                          delay: flight.delay, arrival: flight.arrival, layer: flight.layer)
        }
        flights += numbered
        return numbered
    }

    /// The flight has finished: it stops being drawn, and what it carried shows where it landed.
    mutating func land(_ flight: Flight, handNumber: Int) {
        flights.removeAll { $0.id == flight.id }
        switch flight.arrival {
        case let .field(index): landedPlays = max(landedPlays, index + 1)
        case let .hand(card): dealtCards.insert(card)
        case .none: break
        }
        // Once no dealt card is still in the air, the whole hand is in the player's hand.
        if dealStarted == handNumber, dealtHand < handNumber,
           !flights.contains(where: { if case .hand = $0.arrival { true } else { false } }) {
            dealtHand = handNumber
            dealtCards = []
        }
    }

    /// Brings what has landed up to date for one accepted action. Flights themselves are planned by the table.
    mutating func apply(_ change: MotionSnapshot.Change, to match: Match, dealPending: Bool = false) {
        switch change {
        // A new hand: none of its plays is on the field yet, whatever the last hand left in the count.
        case .dealt: landedPlays = 0
        case .reset: reset(to: match, dealPending: dealPending)
        case .played, .quiet: break
        }
    }

    /// What the table does about the current hand's deal: nothing (it has begun, or there is none to do), fly it, or
    /// skip it so the hand shows at once. A deal that can no longer run, because the auction has moved on or the
    /// curtain is up or motion is reduced, is skipped rather than left waiting, so no card stays hidden.
    enum DealStep: Equatable { case none, animate, skip }

    func dealStep(for hand: Hand, handNumber: Int, canAnimate: Bool) -> DealStep {
        guard dealStarted < handNumber, dealtHand < handNumber else { return .none }
        return canAnimate && RiffleShuffle.startsHand(hand) ? .animate : .skip
    }

    mutating func skipDeal(handNumber: Int) {
        dealStarted = handNumber
        dealtHand = max(dealtHand, handNumber)
        dealtCards = []
    }

    /// Whether a play, by its index in the hand, has reached the field.
    func hasLanded(playIndex: Int) -> Bool { playIndex < landedPlays }

    /// Whether a card of the player's hand is in it yet, or still being dealt.
    func isInHand(_ card: Card, handNumber: Int) -> Bool { handNumber <= dealtHand || dealtCards.contains(card) }
}

/// What the motion planner needs to know about the match after each action.
struct MotionSnapshot: Equatable {
    let handNumber: Int
    let actionCount: Int
    /// Every play of the current hand in order: the completed tricks', then the current one's.
    let plays: [Play]
    /// A hand just dealt: bidding, and nobody has called.
    let freshHand: Bool

    init(match: Match) {
        handNumber = match.handNumber
        actionCount = match.actionCount
        plays = match.hand.completedTricks.flatMap(\.plays) + match.hand.currentTrick
        freshHand = RiffleShuffle.startsHand(match.hand)
    }

    /// What one accepted action did, as far as the table's motion is concerned.
    enum Change: Equatable {
        /// One card went onto the field; `index` counts the hand's plays from zero.
        case played(Play, index: Int)
        /// The next hand was dealt.
        case dealt
        /// Bids and trump: nothing flies.
        case quiet
        /// Anything that is not one step forward (undo, a new game, a restore): put everything where it is.
        case reset
    }

    static func change(from old: MotionSnapshot, to new: MotionSnapshot) -> Change {
        if new.handNumber == old.handNumber, new.actionCount == old.actionCount + 1 {
            if new.plays.count == old.plays.count + 1, Array(new.plays.prefix(old.plays.count)) == old.plays, let play = new.plays.last {
                return .played(play, index: new.plays.count - 1)
            }
            return new.plays == old.plays ? .quiet : .reset
        }
        if new.handNumber == old.handNumber + 1, new.actionCount == old.actionCount + 1, new.freshHand { return .dealt }
        if new == old { return .quiet }
        return .reset
    }
}

/// The table's measurements the planner flies between, all in the table's coordinate space.
struct TableGeometry: Equatable {
    /// The middle of the field, where the pile's offsets start, and how much the pile's cards are scaled.
    var pileCentre: CGPoint?
    var pileScale = 1.0
    var pileRise = Theme.Table.trickRise
    /// Each place round the table (0 you, 1 left, 2 across, 3 right): the centre of that seat's face, and for you the
    /// name under your hand.
    var seats: [Int: CGPoint] = [:]
    /// The dealer's deck.
    var deck: CGPoint?
    /// How your hand is laid out, for dealing into it and playing out of it.
    var hand: HandFanView.Geometry?
}

/// Builds flights from the table's measurements (D97). Pure: the same match and geometry give the same flights.
enum FlightPlan {
    /// Where a play rests on the field: its seat's nudge from the pile's centre plus its own toss.
    static func rest(place: Int, card: Card, handNumber: Int, trickIndex: Int, pileCentre: CGPoint, scale: Double = 1, rise: Double = Theme.Table.trickRise) -> CardPose {
        let toss = CardToss.pose(for: card, hand: handNumber, trick: trickIndex)
        let nudge = TableSurface.pileOffset(for: place, scale: scale, rise: rise)
        return CardPose(centre: CGPoint(x: pileCentre.x + nudge.width + toss.offset.width,
                                        y: pileCentre.y + nudge.height + toss.offset.height),
                        rotation: toss.rotation, scale: scale)
    }

    /// A computer's card leaves its player's face, small as if from their hand, and lands on its spot.
    static func play(_ play: Play, index: Int, place: Int, handNumber: Int, geometry: TableGeometry,
                     launch: CardPose? = nil) -> Flight? {
        guard let centre = geometry.pileCentre else { return nil }
        let rest = rest(place: place, card: play.card, handNumber: handNumber, trickIndex: index / 4, pileCentre: centre, scale: geometry.pileScale, rise: geometry.pileRise)
        let from: CardPose
        if let launch {
            from = launch
        } else if let seat = geometry.seats[place] {
            let turn = place == 1 ? -18.0 : place == 3 ? 18 : 0
            from = CardPose(centre: seat, rotation: rest.rotation + turn, scale: 0.42)
        } else {
            return nil
        }
        // A thrown card curves a little toward the table's middle on its way in.
        let arc = place == 1 ? -14.0 : place == 3 ? 14 : 0
        return Flight(id: 0, card: play.card, width: Theme.Card.pileWidth, from: from,
                      legs: [.init(to: rest, seconds: Theme.Motion.playSeconds, ease: .out, arc: arc)],
                      arrival: .field(playIndex: index), layer: Double(index))
    }

    /// A finished trick: the four cards gather onto the winning card, then are pulled to the winner's seat and fade
    /// into it. The winner's card stays on top.
    static func collect(_ trick: CompletedTrick, trickIndex: Int, handNumber: Int, places: (Int) -> Int,
                        geometry: TableGeometry) -> [Flight] {
        guard let centre = geometry.pileCentre else { return [] }
        let winnerPlace = places(trick.winner)
        let target = geometry.seats[winnerPlace] ?? CGPoint(x: centre.x, y: centre.y + 400)
        guard let winning = trick.plays.first(where: { $0.seat == trick.winner }) else { return [] }
        let stack = rest(place: winnerPlace, card: winning.card, handNumber: handNumber, trickIndex: trickIndex, pileCentre: centre, scale: geometry.pileScale, rise: geometry.pileRise)
        return trick.plays.enumerated().map { order, play in
            let from = rest(place: places(play.seat), card: play.card, handNumber: handNumber, trickIndex: trickIndex, pileCentre: centre, scale: geometry.pileScale, rise: geometry.pileRise)
            let isWinner = play.seat == trick.winner
            let spread = Double(order) - 1.5
            let gathered = CardPose(centre: CGPoint(x: stack.centre.x + spread * 1.2, y: stack.centre.y - spread * 1.2),
                                    rotation: stack.rotation + (isWinner ? 0 : spread * 4))
            // Most of the way in at full size and opacity, then smaller and gone as it reaches the seat.
            let near = CGPoint(x: gathered.centre.x + (target.x - gathered.centre.x) * 0.8,
                               y: gathered.centre.y + (target.y - gathered.centre.y) * 0.8)
            let towards = CardPose(centre: near, rotation: stack.rotation * 0.3, scale: 0.55)
            let gone = CardPose(centre: target, rotation: 0, scale: 0.34, opacity: 0)
            return Flight(id: 0, card: play.card, width: Theme.Card.pileWidth, from: from,
                          legs: [.init(to: gathered, seconds: Theme.Motion.gatherSeconds, ease: .inOut),
                                 .init(to: towards, seconds: Theme.Motion.takeSeconds * 0.72, ease: .into),
                                 .init(to: gone, seconds: Theme.Motion.takeSeconds * 0.28, ease: .linear)],
                          layer: 20 + (isWinner ? 10 : Double(order)))
        }
    }

    /// The deal (D97): two rounds of three to each seat, starting on the dealer's left, from the dealer's deck. Your
    /// own cards land in their places in your hand edge-on, and turn face up there; everyone else's go into their seat.
    static func deal(dealerPlace: Int, yourCards: [Card], geometry: TableGeometry) -> [Flight] {
        guard let deck = geometry.deck else { return [] }
        var flights: [Flight] = []
        var packet = 0
        for round in 0..<2 {
            for step in 1...4 {
                let place = (dealerPlace + step) % 4
                for card in 0..<3 {
                    let delay = Theme.Motion.dealStart + Double(packet) * Theme.Motion.dealPacketGap + Double(card) * Theme.Motion.dealCardGap
                    let slot = round * 3 + card
                    if place == 0 {
                        guard slot < yourCards.count, let hand = geometry.hand,
                              let pose = hand.pose(slot: slot, count: yourCards.count, flat: true) else { continue }
                        let width = hand.baseWidth
                        let from = CardPose(centre: deck, rotation: -8, scale: Theme.Table.dealerMarkDeckWidth / width)
                        var landed = pose
                        landed.turn = 90
                        flights.append(Flight(id: 0, card: nil, width: width, from: from,
                                              legs: [.init(to: landed, seconds: Theme.Motion.dealCardSeconds, ease: .out, arc: 10)],
                                              delay: delay, arrival: .hand(yourCards[slot]), layer: 40 + Double(slot)))
                    } else if let seat = geometry.seats[place] {
                        let spread = Double(card) - 1
                        let width = Theme.Card.pileWidth
                        let from = CardPose(centre: deck, rotation: -8, scale: Theme.Table.dealerMarkDeckWidth / width)
                        let near = CGPoint(x: seat.x + spread * 7, y: seat.y + 6)
                        flights.append(Flight(id: 0, card: nil, width: width, from: from,
                                              legs: [.init(to: CardPose(centre: near, rotation: spread * 10, scale: 0.5),
                                                           seconds: Theme.Motion.dealCardSeconds * 0.85, ease: .out, arc: 10),
                                                     .init(to: CardPose(centre: seat, rotation: spread * 10, scale: 0.38, opacity: 0),
                                                           seconds: Theme.Motion.dealCardSeconds * 0.3, ease: .linear)],
                                              delay: delay, layer: 30 + Double(packet)))
                    }
                }
                packet += 1
            }
        }
        return flights
    }
}

/// Draws every card in the air above the table. It takes no touches and VoiceOver never meets it: the cards it draws
/// are also on the table, where VoiceOver reads them.
struct FlightLayer: View {
    let flights: [Flight]

    var body: some View {
        // Nothing but the cards in the air: no backdrop, so the layer never stands between a finger, or VoiceOver,
        // and the table.
        ZStack(alignment: .topLeading) {
            ForEach(flights) { flight in
                FlightView(flight: flight).zIndex(flight.layer).accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dynamicTypeSize(.large)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// One flight, run once from its launch to its landing.
private struct FlightView: View {
    let flight: Flight
    @State private var elapsed = 0.0

    var body: some View {
        Group {
            if let card = flight.card {
                CardView(card: card, width: flight.width, style: .pile)
            } else {
                CardBackView(width: flight.width)
            }
        }
        .modifier(FlightPath(flight: flight, elapsed: elapsed))
        .onAppear {
            withAnimation(.linear(duration: flight.duration).delay(flight.delay)) { elapsed = flight.duration }
        }
    }
}

/// Places a card at its flight's pose for the elapsed time; SwiftUI animates `elapsed` and this reads the path.
private struct FlightPath: ViewModifier, @preconcurrency Animatable {
    let flight: Flight
    var elapsed: Double
    var animatableData: Double {
        get { elapsed }
        set { elapsed = newValue }
    }

    func body(content: Content) -> some View {
        let pose = flight.pose(at: elapsed)
        // A delayed flight is not drawn before it leaves: the deck it starts from is already there.
        let started = elapsed > 0 || flight.delay == 0
        content
            .rotation3DEffect(.degrees(pose.turn), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
            .rotationEffect(.degrees(pose.rotation))
            .scaleEffect(pose.scale)
            .opacity(started ? pose.opacity : 0)
            .position(pose.centre)
    }
}
