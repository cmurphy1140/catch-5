import CatchFive
import SwiftUI

/// The human's hand: six overlapped cards on a shallow fan, the dominant element on screen.
struct HandFanView: View {
    @ObservedObject var model: GameModel
    /// Called with the card when a tap is refused, so the table can shake it and buzz.
    let onIllegal: (Card) -> Void
    @Binding var shakes: [Card: Int]
    /// The card picked by the first tap (D97); a second tap, or dragging it up, plays it.
    @Binding var selected: Card?
    /// Cards of a hand still being dealt (D97): their places are kept, but they are not drawn until they land.
    var dealing: Set<Card> = []
    /// The centre of the deck beside the dealer, in the table's coordinate space; the refill deals in from it.
    var deck: CGPoint? = nil
    /// Your own deck, under the fan when you deal, says where it rests.
    var onDeck: (CGPoint) -> Void = { _ in }
    /// The phone holder's tag was tapped: rename that seat (D93).
    var onRename: (Int) -> Void = { _ in }
    /// Your own face by your hand was tapped: open Support (D115).
    var onSupport: () -> Void = {}
    /// Goes up when your spot on the table is tapped: the picked card is played from where it stands (D116).
    var layDown = 0
    /// Your face by your hand: a thumb and a bit, large enough to read as a person and to hold its help bubble.
    nonisolated static let faceSize = 54.0
    private var plate: Bool { model.settings.tableArrangement != .classic }
    /// How the hand is laid out, so the table can deal into it and fly a played card out of it (D97).
    var onGeometry: (Geometry) -> Void = { _ in }
    /// Where your name sits under the hand: a trick you take is pulled toward it.
    var onAnchor: (CGPoint) -> Void = { _ in }
    /// Told where a card was, in the table's space, just before it is played, so its flight starts there.
    var onLaunch: (Card, CardPose) -> Void = { _, _ in }
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var scaledStandard = Theme.Card.handWidth
    @ScaledMetric(relativeTo: .title2) private var scaledWide = Theme.Card.handWidthWide
    /// The width the hand was actually given, so the arrangement is decided from a measurement.
    @State private var measuredWidth = 0.0
    /// Where the hand sits on the table, so a dealt card knows how far it has come from the deck.
    @State private var fanFrame = CGRect.zero
    /// The card being dragged and how far it has moved. Gesture state, so a cancelled touch can never leave a card
    /// hanging in the air; letting go short of a play springs it back.
    @GestureState(resetTransaction: Transaction(animation: .spring(duration: 0.35, bounce: 0.3))) private var drag: Drag?
    /// The card under a finger right now: it rises a little before anything is decided.
    @GestureState private var pressing: Card?

    struct Drag: Equatable {
        let card: Card
        let offset: CGSize
    }

    /// Where a dragged card is drawn for a finger's travel: it follows the finger upward freely; sideways and down it
    /// resists, so it reads as lifting.
    nonisolated static func dragOffset(_ translation: CGSize) -> CGSize {
        // The card follows upward one to one, half as much sideways, and resists downward at 0.3.
        CGSize(width: translation.width * 0.5, height: min(translation.height, translation.height * 0.3))
    }

    private var wide: Bool { measuredWidth + 2 * Theme.Table.horizontalInset >= Theme.Card.wideScreenWidth }
    private var cardWidth: Double {
        guard measuredWidth > 0 else { return wide ? scaledWide : scaledStandard }
        return HandLayout.fittedCardWidth(preferred: wide ? scaledWide : scaledStandard, available: measuredWidth - 16)
    }
    private var scaledWidth: Double { cardWidth }
    /// Fan or two rows: whichever keeps every card's exposed strip at least 44 pt (`HandLayout`).
    private var arrangement: HandLayout.Arrangement {
        // Before the first measurement the fan keeps its natural overlap; deciding on a zero width would
        // pick two rows and then tear the fan down once the real width lands.
        guard measuredWidth > 0 else { return .fan(strip: Theme.Card.touchStrip(width: scaledWidth)) }
        return HandLayout.arrange(count: model.humanCards.count, cardWidth: scaledWidth, available: measuredWidth - 16)
    }

    private var geometry: Geometry {
        Geometry(frame: fanFrame, baseWidth: cardWidth, scaledWidth: scaledWidth, available: measuredWidth - 16)
    }

    var body: some View {
        let cards = model.humanCards
        let arrangement = arrangement
        VStack(spacing: 6) {
            Group {
                switch arrangement {
                case .fan where model.match.hand.phase == .bidding && measuredWidth > 0:
                    // B01: while bidding, the hand lies flat on one baseline, evenly spaced; the fan comes back after.
                    row(cards, indices: Array(cards.indices), strip: HandLayout.baselineStrip(count: cards.count, cardWidth: scaledWidth,
                                                                                           available: measuredWidth - 16), fanned: false)
                case let .fan(strip):
                    row(cards, indices: Array(cards.indices), strip: strip, fanned: true)
                case let .rows(perRow, strip):
                    VStack(spacing: HandLayout.rowGap) {
                        row(cards, indices: Array(0..<min(perRow, cards.count)), strip: strip, fanned: false)
                        if cards.count > perRow { row(cards, indices: Array(perRow..<cards.count), strip: strip, fanned: false) }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .bottom)
            .onChange(of: layDown) {
                guard let card = selected, let slot = cards.firstIndex(of: card), model.allows(.play(card)) else { return }
                var fanned = false
                if case .fan = arrangement { fanned = true }
                play(card, slot: slot, count: cards.count, fanned: fanned, extra: .zero)
            }
            .frame(height: HandLayout.height(of: arrangement, cardWidth: scaledWidth,
                                             flat: model.match.hand.phase == .bidding && measuredWidth > 0))
            .onGeometryChange(for: Double.self) { $0.size.width } action: { measuredWidth = $0 }
            .onGeometryChange(for: CGRect.self) { $0.frame(in: .named(TableLayout.space)) } action: { fanFrame = $0 }
            .onChange(of: geometry, initial: true) { _, geometry in onGeometry(geometry) }
            // No "Your hand" caption (T05). Under the hand, the phone holder's name carved into the wood, trump beside it
            // when they bid (D94), a tap renames them (D93), and, when yours, the deal with its dealer button.
            HStack(spacing: 10) {
                if let seat = model.viewerSeat {
                    let hand = model.match.hand
                    if plate { Spacer(minLength: 0) }
                    HStack(spacing: 4) {
                    // Your own face (D115), with a help bubble on its rim: a tap opens Support.
                    Button(action: onSupport) {
                        Group {
                            // Your own figure as a cut-out (D148) when the build has one, else the drawn face.
                            if let art = SeatArt.image(seat: seat, opponents: model.settings.opponents) {
                                art.resizable().scaledToFit().frame(width: Self.faceSize * 1.25, height: Self.faceSize)
                                    // Drawn half as big again without moving the row (D157): it grows up and away from the name.
                                    .scaleEffect(1.5, anchor: .bottomTrailing)
                            } else {
                                PortraitView(portrait: Cast.opponent(at: seat)?.portrait ?? model.settings.playerPortrait, size: Self.faceSize,
                                             rim: SeatView.rim(seat: seat, ourTeam: model.ourTeam), rimWidth: Theme.Team.rimWidth)
                            }
                        }
                            .padding(.trailing, 6)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Support")
                    .accessibilityHint("Rules, scoring and advice; pauses play")
                    // When the dealer's deck shares the row, the side word yields before the name is cut short.
                    ViewThatFits(in: .horizontal) {
                        ForEach(["US", nil] as [String?], id: \.self) { side in
                            NameTag(name: model.seatNames[seat], trump: SeatView.carvedTrump(seat: seat, bidder: hand.auction.winner, trump: hand.trump), inlaid: plate, side: side)
                                .renames { onRename(seat) }
                        }
                    }
                        .onGeometryChange(for: CGPoint.self) { proxy in
                            let frame = proxy.frame(in: .named(TableLayout.space))
                            return CGPoint(x: frame.midX, y: frame.midY)
                        } action: { onAnchor($0) }
                    }
                    // On the cloth tables the face and name share a dark nameplate, centred under the hand (D117).
                    .padding(.trailing, plate ? 22 : 0)
                    // The name keeps its width; the help bubble beside it shortens first (D158).
                    .layoutPriority(1)
                    .background {
                        if plate {
                            Capsule().fill(Theme.Wood.header.opacity(0.8))
                                .overlay(Capsule().stroke(Theme.Paper.rule.opacity(0.7), lineWidth: 1.5))
                                .padding(.leading, Self.faceSize / 2).padding(.vertical, 5)
                        }
                    }
                    // Help is a speech bubble beside your name (D158), not a badge on your face.
                    Button(action: onSupport) {
                        ViewThatFits(in: .horizontal) {
                            HelpBubbleLabel(words: "ChatGPT help")
                            HelpBubbleLabel(words: "Help")
                            HelpBubbleLabel(words: "")
                        }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("ChatGPT help")
                    .accessibilityHint("Rules, scoring and advice; pauses play")
                }
                Spacer(minLength: 0)
                if !cards.isEmpty, model.match.hand.auction.dealer == model.viewerSeat {
                    DealerMark(onPlaced: onDeck, sideways: DealerMark.placement(forPlace: 0) == .besideYourName)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// One row of cards. Fanned rows rotate and dip; the two-row fallback lays cards flat so nothing
    /// overlaps a neighbour's touch strip.
    private func row(_ cards: [Card], indices: [Int], strip: Double, fanned: Bool) -> some View {
        let playing = model.match.hand.phase == .playing
        let fanCount = fanned ? cards.count : 1
        return HStack(spacing: strip - scaledWidth) {
            // Keyed by the card, not its place (D97): a played card's own view leaves (its flight carries it), a discard's
            // own view flies to the pile, and no other card inherits an animation meant for one of them.
            ForEach(indices.map { (index: $0, card: cards[$0]) }, id: \.card) { index, card in
                let playable = model.allows(.play(card))
                let isSelected = selected == card && playable
                let dragged = drag?.card == card ? drag?.offset ?? .zero : .zero
                let style: CardStyle = playing && model.isHumanTurn ? (playable ? .playable : .dimmed) : .rest
                let inHand = !dealing.contains(card)
                CardView(card: card, width: cardWidth, style: style)
                    .dynamicTypeSize(.large)
                    .overlay(RoundedRectangle(cornerRadius: Theme.Card.radius(width: cardWidth), style: .continuous)
                        .strokeBorder(.ivory.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                        .opacity(model.hint?.action == .play(card) ? 1 : 0))
                    // The touch target is the card itself, before it is turned, lifted or dragged, so it travels with
                    // the card and a raised card is tapped where it is drawn.
                    .contentShape(Rectangle())
                    .gesture(cardGesture(card, slot: index, count: cards.count, fanned: fanned, playable: playable))
                    // The picked card glows warm along its edge, so the second tap has an obvious target. It keeps its
                    // place in the stack, so the next card's corner stays on top of it and is still that card's to tap.
                    .shadow(color: Theme.Field.lamp.opacity(isSelected ? 0.75 : 0), radius: isSelected ? 10 : 0)
                    .modifier(ShakeEffect(trigger: shakes[card, default: 0]))
                    .rotationEffect(.degrees(reduceMotion || !fanned ? 0 : Self.fanAngle(index, of: fanCount)), anchor: .bottom)
                    .offset(y: reduceMotion || !fanned ? 0 : Self.fanDrop(index, of: fanCount))
                    .offset(y: isSelected ? -Theme.Card.liftSelected : 0)
                    .offset(y: pressing == card && playable && !isSelected && !reduceMotion ? -Theme.Card.liftPressed : 0)
                    .offset(dragged)
                    // A dealt card arrives edge-on from the deck and turns face up in its place.
                    .rotation3DEffect(.degrees(inHand || reduceMotion ? 0 : 90), axis: (x: 0, y: 1, z: 0), perspective: 0.4)
                    .opacity(inHand ? 1 : 0)
                    // Under Reduce Motion a picked card simply stands up; nothing slides.
                    .animation(reduceMotion ? nil : Theme.Motion.press, value: isSelected)
                    .animation(reduceMotion ? nil : Theme.Motion.press, value: pressing)
                    .allowsHitTesting(playing && inHand)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(card.spoken)
                    .accessibilityValue(model.accessibilityValue(for: card))
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityHint(isSelected ? "Tap again, or tap your spot on the table, to play" : playable ? "Picks this card; tap again to play it" : "")
                    .accessibilityAction { activate(card, slot: index, count: cards.count, fanned: fanned, playable: playable) }
                    .transition(handTransition(index: index, slot: indices.firstIndex(of: index) ?? 0, count: indices.count, strip: strip))
                    .zIndex(drag?.card == card ? 200 : Double(index))
            }
        }
    }

    /// One gesture for a hand card (D97): a touch that does not travel is a tap; one that travels drags a legal card,
    /// and letting go high enough plays it, lower and it springs back. A card that may not be played shakes and the
    /// table says why, whether it was tapped or dragged.
    private func cardGesture(_ card: Card, slot: Int, count: Int, fanned: Bool, playable: Bool) -> some Gesture {
        DragGesture(minimumDistance: 0, coordinateSpace: .named(TableLayout.space))
            .updating($pressing) { _, state, _ in state = card }
            .updating($drag) { value, state, _ in
                guard playable, hypot(value.translation.width, value.translation.height) > 8 else { return }
                state = Drag(card: card, offset: Self.dragOffset(value.translation))
            }
            .onEnded { value in
                let travel = hypot(value.translation.width, value.translation.height)
                if travel <= 8 || !playable {
                    activate(card, slot: slot, count: count, fanned: fanned, playable: playable)
                } else if -value.translation.height >= Theme.Card.dragToPlay, model.allows(.play(card)) {
                    play(card, slot: slot, count: count, fanned: fanned, extra: Self.dragOffset(value.translation))
                }
            }
    }

    /// A tap: the first picks a playable card, the second on the same card plays it; a card that may not be played
    /// shakes and the table says why.
    private func activate(_ card: Card, slot: Int, count: Int, fanned: Bool, playable: Bool) {
        guard model.allows(.play(card)) else {
            onIllegal(card)
            selected = nil
            return
        }
        if selected == card {
            play(card, slot: slot, count: count, fanned: fanned, extra: .zero)
        } else {
            model.clearRefusal()
            selected = card
        }
    }

    private func play(_ card: Card, slot: Int, count: Int, fanned: Bool, extra: CGSize) {
        let lift = (selected == card ? Theme.Card.liftSelected : 0) + Theme.Card.liftPlayable
        if var pose = geometry.pose(slot: slot, count: count, flat: !fanned || reduceMotion, lift: lift) {
            pose.centre.x += extra.width
            pose.centre.y += extra.height
            pose.scale = cardWidth / Theme.Card.pileWidth
            onLaunch(card, pose)
        }
        selected = nil
        model.send(.play(card))
    }

    /// How a card enters or leaves the fan. A played card leaves by flight (identity here). While trump is being
    /// chosen, a leaving card is a discard: it rises toward the table and fades, one after another. At the start of
    /// play, an arriving card is part of the refill: it deals in from the deck beside the dealer, deck-sized and faint,
    /// after the discards have gone. A fresh hand's cards are dealt by the table's flights, so they enter as they are.
    private func handTransition(index: Int, slot: Int, count: Int, strip: Double) -> AnyTransition {
        if reduceMotion { return .opacity }
        let hand = model.match.hand
        let dealing = hand.phase == .playing && hand.currentTrick.isEmpty && hand.completedTricks.isEmpty
        // Until the deck has said where it rests, a refill card fades in where it lands.
        let flight = deck.map { Self.dealOrigin(slot: slot, count: count, strip: strip, cardWidth: scaledWidth, in: fanFrame, deck: $0) } ?? .zero
        let insertion: AnyTransition = dealing
            ? .offset(flight)
                .combined(with: .scale(scale: Theme.Table.dealerMarkDeckWidth / scaledWidth)).combined(with: .opacity)
                .animation(Theme.Motion.flight.delay(Theme.Motion.dealDelay + Double(index) * Theme.Motion.dealStagger))
            : .identity
        // A discard flies to the pile in the top-left corner, shrinking to a card back.
        let removal: AnyTransition = hand.phase == .choosingTrump
            ? .offset(Self.discardTarget(index: index, count: model.humanCards.count, width: measuredWidth))
                .combined(with: .scale(scale: Theme.Table.deckWidth / scaledWidth)).combined(with: .opacity)
                .animation(Theme.Motion.collapse.delay(Double(index) * Theme.Motion.discardStagger))
            : .identity
        return .asymmetric(insertion: insertion, removal: removal)
    }

    /// Where a card of a row comes to rest: `strip` apart around the middle of the hand's `frame`, on its
    /// bottom edge. `slot` counts from the left of the row.
    nonisolated static func cardCentre(slot: Int, count: Int, strip: Double, cardWidth: Double, in frame: CGRect) -> CGPoint {
        CGPoint(x: frame.midX + (Double(slot) - Double(count - 1) / 2) * strip,
                y: frame.maxY - cardWidth * Theme.Card.ratio / 2)
    }

    /// Where a dealt card starts, relative to its place in the fan: the deck beside the dealer (T12), wherever
    /// that seat sits. `frame` and `deck` share the table's coordinate space.
    nonisolated static func dealOrigin(slot: Int, count: Int, strip: Double, cardWidth: Double, in frame: CGRect, deck: CGPoint) -> CGSize {
        let centre = cardCentre(slot: slot, count: count, strip: strip, cardWidth: cardWidth, in: frame)
        return CGSize(width: deck.x - centre.x, height: deck.y - centre.y)
    }

    /// Where a discard lands: the pile in the top-left corner, level with the deck (spec R3).
    nonisolated static func discardTarget(index: Int, count: Int, width: Double) -> CGSize {
        let cardCentre = (Double(index) + 0.5) * width / Double(max(count, 1))
        return CGSize(width: Theme.Table.deckWidth * 0.85 / 2 - cardCentre, height: -Theme.Table.deckRise)
    }

    /// Cards rotate from −8° on the left to +8° on the right about their bottom edge.
    nonisolated static func fanAngle(_ index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let t = Double(index) / Double(count - 1)
        return (t - 0.5) * 2 * Theme.Card.fanRotationDegrees
    }

    /// The outer cards sit a little lower so the tops trace a shallow arc.
    nonisolated static func fanDrop(_ index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let t = Double(index) / Double(count - 1)
        return pow((t - 0.5) * 2, 2) * Theme.Card.fanDrop
    }

    /// The hand's layout as the table needs it (D97): where each card of a hand of a given size is drawn, in the
    /// table's space, so a dealt card can land in its place and a played card can leave from it.
    struct Geometry: Equatable {
        /// The cards' row, in the table's coordinate space; the row is centred in it.
        var frame: CGRect
        /// The card width before it scales with the reader's text size, and after.
        var baseWidth: Double
        var scaledWidth: Double
        /// The width a row may use.
        var available: Double

        /// The pose of card `slot` of `count`: lying flat in a row (the auction, or Reduce Motion) or fanned, and
        /// raised by `lift`. Nil before the hand has been measured.
        func pose(slot: Int, count: Int, flat: Bool, lift: Double = 0) -> CardPose? {
            guard count > 0, slot < count, frame.width > 0, available > 0 else { return nil }
            let height = scaledWidth * Theme.Card.ratio
            switch HandLayout.arrange(count: count, cardWidth: scaledWidth, available: available) {
            case let .fan(strip):
                if flat {
                    let step = HandLayout.baselineStrip(count: count, cardWidth: scaledWidth, available: available)
                    return CardPose(centre: CGPoint(x: frame.midX + (Double(slot) - Double(count - 1) / 2) * step, y: frame.midY - lift))
                }
                // Turned about its bottom edge, then dropped along the arc.
                let angle = HandFanView.fanAngle(slot, of: count), radians = angle * .pi / 180
                let x = frame.midX + (Double(slot) - Double(count - 1) / 2) * strip
                return CardPose(centre: CGPoint(x: x + height / 2 * sin(radians),
                                                y: frame.midY + height / 2 * (1 - cos(radians)) + HandFanView.fanDrop(slot, of: count) - lift),
                                rotation: angle)
            case let .rows(perRow, strip):
                let row = slot < perRow ? 0 : 1
                let inRow = row == 0 ? min(perRow, count) : count - perRow
                let position = row == 0 ? slot : slot - perRow
                let top = frame.midY - (2 * height + HandLayout.rowGap) / 2
                return CardPose(centre: CGPoint(x: frame.midX + (Double(position) - Double(inRow - 1) / 2) * strip,
                                                y: top + height / 2 + Double(row) * (height + HandLayout.rowGap) - lift))
            }
        }
    }
}

/// Three quick side-to-side oscillations over 0.3 s; runs whenever `trigger` changes.
struct ShakeEffect: ViewModifier {
    let trigger: Int
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func body(content: Content) -> some View {
        // Under Reduce Motion nothing moves; the refusal reason on the message line does the talking.
        let a = reduceMotion ? 0 : Theme.Motion.shakeAmplitude
        content.keyframeAnimator(initialValue: 0.0, trigger: trigger) { view, x in
            view.offset(x: x)
        } keyframes: { _ in
            KeyframeTrack(\.self) {
                CubicKeyframe(-a, duration: 0.05)
                CubicKeyframe(a, duration: 0.08)
                CubicKeyframe(-a * 0.8, duration: 0.07)
                CubicKeyframe(a * 0.5, duration: 0.05)
                CubicKeyframe(0, duration: 0.05)
            }
        }
    }
}

/// The help button's face (D158): three dots and a word or two in a green speech bubble whose tail points back at you.
struct HelpBubbleLabel: View {
    let words: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "ellipsis").font(.system(size: 15, weight: .heavy))
            if !words.isEmpty { Text(words).font(.system(size: 17, weight: .bold, design: .serif)).lineLimit(1).fixedSize() }
        }
        .foregroundStyle(.ivory)
        .padding(.leading, 20).padding(.trailing, 14)
        .frame(height: 44)
        .background {
            SpeechBubble(tail: .leading).fill(Theme.Paper.green)
                .overlay(SpeechBubble(tail: .leading).stroke(.ivory.opacity(0.35), lineWidth: 1))
                .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                .padding(.vertical, 3)
        }
        .contentShape(Rectangle())
    }
}
