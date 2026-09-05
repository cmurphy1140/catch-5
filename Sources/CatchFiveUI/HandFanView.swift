import CatchFive
import SwiftUI

/// The human's hand: six overlapped cards on a shallow fan, the dominant element on screen.
struct HandFanView: View {
    @ObservedObject var model: GameModel
    let namespace: Namespace.ID
    /// Called with the card when a tap is refused, so the table can shake it and buzz.
    let onIllegal: (Card) -> Void
    @Binding var shakes: [Card: Int]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title2) private var scaledStandard = Theme.Card.handWidth
    @ScaledMetric(relativeTo: .title2) private var scaledWide = Theme.Card.handWidthWide

    var body: some View {
        let cards = model.humanCards
        let playing = model.match.hand.phase == .playing
        VStack(spacing: 6) {
            // The fan fits the available width: the overlap tightens when Dynamic Type grows the cards.
            GeometryReader { geometry in
                let wide = geometry.size.width + 32 >= Theme.Card.wideScreenWidth
                let width = wide ? Theme.Card.handWidthWide : Theme.Card.handWidth
                let scaled = wide ? scaledWide : scaledStandard
                let strip = min(scaled + Theme.Card.handOverlap, (geometry.size.width - 16 - scaled) / Double(max(cards.count - 1, 1)))
                HStack(spacing: strip - scaled) {
                ForEach(Array(cards.enumerated()), id: \.element) { index, card in
                    let playable = model.allows(.play(card))
                    let style: CardStyle = playing && model.isHumanTurn ? (playable ? .playable : .dimmed) : .rest
                    Button {
                        if playable { model.send(.play(card)) } else { onIllegal(card) }
                    } label: {
                        CardView(card: card, width: width, style: style)
                            .overlay(RoundedRectangle(cornerRadius: Theme.Card.radius(width: width), style: .continuous)
                                .strokeBorder(.ivory.opacity(0.9), style: StrokeStyle(lineWidth: 2, dash: [4, 3]))
                                .opacity(model.hint?.action == .play(card) ? 1 : 0))
                    }
                    .buttonStyle(CardPressStyle(enabled: playable))
                    .modifier(ShakeEffect(trigger: shakes[card, default: 0]))
                    .rotationEffect(.degrees(reduceMotion ? 0 : fanAngle(index, of: cards.count)), anchor: .bottom)
                    .offset(y: reduceMotion ? 0 : fanDrop(index, of: cards.count))
                    .allowsHitTesting(playing)
                    .accessibilityValue(model.accessibilityValue(for: card))
                    .modifier(MatchedCard(card: card, namespace: namespace, enabled: !reduceMotion))
                    .transition(reduceMotion ? .opacity : .identity)
                    .zIndex(Double(index))
                }
                }
                .frame(width: geometry.size.width, height: geometry.size.height, alignment: .bottom)
            }
            .frame(height: max(scaledStandard, scaledWide) * Theme.Card.ratio + 16 + Theme.Card.fanDrop)
            if !cards.isEmpty {
                Text("YOUR HAND").font(.caption2.monospaced()).tracking(1).opacity(0.55)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Cards rotate from −8° on the left to +8° on the right about their bottom edge.
    private func fanAngle(_ index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let t = Double(index) / Double(count - 1)
        return (t - 0.5) * 2 * Theme.Card.fanRotationDegrees
    }

    /// The outer cards sit a little lower so the tops trace a shallow arc.
    private func fanDrop(_ index: Int, of count: Int) -> Double {
        guard count > 1 else { return 0 }
        let t = Double(index) / Double(count - 1)
        return pow((t - 0.5) * 2, 2) * Theme.Card.fanDrop
    }
}

/// Three quick side-to-side oscillations over 0.3 s; runs whenever `trigger` changes.
struct ShakeEffect: ViewModifier {
    let trigger: Int
    func body(content: Content) -> some View {
        let a = Theme.Motion.shakeAmplitude
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

/// Joins a hand card to its pile counterpart so a play flies between them; off under Reduce Motion.
struct MatchedCard: ViewModifier {
    let card: Card
    let namespace: Namespace.ID
    let enabled: Bool
    func body(content: Content) -> some View {
        if enabled { content.matchedGeometryEffect(id: card, in: namespace) } else { content }
    }
}
