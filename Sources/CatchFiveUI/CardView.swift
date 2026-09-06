import CatchFive
import SwiftUI

extension Suit {
    var glyph: String {
        switch self {
        case .clubs: "♣"
        case .diamonds: "♦"
        case .hearts: "♥"
        case .spades: "♠"
        }
    }
    var ink: Color { self == .hearts || self == .diamonds ? Color(red: 0.7, green: 0.12, blue: 0.18) : .black }
}

extension Rank {
    /// The corner-index letter or number: A, K, Q, J, else the pip count.
    var label: String {
        switch self {
        case .ace: "A"
        case .king: "K"
        case .queen: "Q"
        case .jack: "J"
        default: String(rawValue)
        }
    }
}

extension Card {
    var label: String { rank.label }
    var spoken: String { name }
}

/// How a card face is drawn: at rest, lifted because it may be played, dimmed because it may not,
/// or flat on the pile. Pressed is applied by `CardPressStyle` on top of these.
enum CardStyle: Equatable {
    case rest, playable, dimmed, pile
}

struct CardView: View {
    let card: Card
    let style: CardStyle
    /// A ring drawn at the card's own scaled radius, so it fits at every text size; nil for none.
    let ring: Color?
    // Cards grow with the reader's text size so the faces stay legible under Dynamic Type.
    @ScaledMetric private var width: Double
    @Environment(\.colorSchemeContrast) private var contrast

    init(card: Card, width: Double = Theme.Card.tutorialWidth, style: CardStyle = .rest, ring: Color? = nil) {
        self.card = card
        self.style = style
        self.ring = ring
        _width = ScaledMetric(wrappedValue: width, relativeTo: .title2)
    }

    var body: some View {
        let radius = Theme.Card.radius(width: width)
        ZStack(alignment: .topLeading) {
            VStack(spacing: 0) {
                Text(card.label).font(.system(size: width * 0.42, weight: .bold, design: .serif))
                Text(card.suit.glyph).font(.system(size: width * 0.46))
            }.frame(maxWidth: .infinity, maxHeight: .infinity)
            // The top-left index is what stays visible when the hand is fanned.
            VStack(spacing: -3) {
                Text(card.label).font(.system(size: max(13, width * 0.2), weight: .bold, design: .serif))
                Text(card.suit.glyph).font(.system(size: max(12, width * 0.18)))
            }.padding(.top, 4).padding(.leading, 5)
        }
        .foregroundStyle(card.suit.ink)
        .frame(width: width, height: width * Theme.Card.ratio)
        .background(.ivory, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.black.opacity(0.15)))
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(ring ?? .clear, lineWidth: 3))
        .shadow(color: .black.opacity(style == .playable ? 0.35 : 0.25), radius: style == .playable ? 8 : 3, y: style == .playable ? 4 : 3)
        .offset(y: style == .playable ? -Theme.Card.liftPlayable : 0)
        // "Not legal now": the card stays opaque but sits in shadow, its colour drained; never see-through.
        .saturation(style == .dimmed ? Theme.Card.dimmedSaturation : 1)
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(.black.opacity(style == .dimmed ? (contrast == .increased ? Theme.Card.dimmedVeilHighContrast : Theme.Card.dimmedVeil) : 0)))
        // With Increase Contrast the dashed edge carries the state as well.
        .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous)
            .strokeBorder(.black.opacity(0.6), style: StrokeStyle(lineWidth: 2, dash: [3, 3]))
            .opacity(style == .dimmed && contrast == .increased ? 1 : 0))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.spoken)
    }
}

/// A face-down card for the opponents' seats.
struct CardBackView: View {
    @ScaledMetric private var width: Double

    init(width: Double = Theme.Card.backWidth) {
        _width = ScaledMetric(wrappedValue: width, relativeTo: .title2)
    }

    var body: some View {
        let radius = Theme.Card.radius(width: width)
        RoundedRectangle(cornerRadius: radius, style: .continuous)
            .fill(Color(red: 0.06, green: 0.22, blue: 0.18))
            .overlay(RoundedRectangle(cornerRadius: radius, style: .continuous).stroke(.ivory.opacity(0.7), lineWidth: 1.5))
            .overlay(RoundedRectangle(cornerRadius: max(2, radius - 3), style: .continuous)
                .stroke(.ivory.opacity(0.35), lineWidth: 1).padding(5))
            .frame(width: width, height: width * Theme.Card.ratio)
            .shadow(color: .black.opacity(0.3), radius: 3, y: 2)
            .accessibilityHidden(true)
    }
}

/// Lifts and slightly enlarges a hand card while it is pressed, before the play is confirmed on release.
struct CardPressStyle: ButtonStyle {
    let enabled: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        let pressed = enabled && configuration.isPressed
        // Under Reduce Motion the press reads as a slight dim rather than a lift.
        configuration.label
            .offset(y: pressed && !reduceMotion ? -Theme.Card.liftPressed : 0)
            .scaleEffect(pressed && !reduceMotion ? Theme.Card.pressedScale : 1)
            .opacity(pressed && reduceMotion ? 0.85 : 1)
            .animation(reduceMotion ? Theme.Motion.reduced : Theme.Motion.press, value: pressed)
    }
}

extension ShapeStyle where Self == Color {
    static var ivory: Color { Color(red: 0.98, green: 0.96, blue: 0.89) }
    static var felt: Color { Color(red: 0.035, green: 0.16, blue: 0.13) }
    static var gold: Color { Color(red: 0.91, green: 0.75, blue: 0.42) }
}
