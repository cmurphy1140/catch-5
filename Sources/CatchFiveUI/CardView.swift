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

extension Card {
    var label: String {
        switch rank {
        case .ace: "A"
        case .king: "K"
        case .queen: "Q"
        case .jack: "J"
        default: String(rank.rawValue)
        }
    }
    var spoken: String { name }
}

struct CardView: View {
    let card: Card
    // Cards grow with the reader's text size so the faces stay legible under Dynamic Type.
    @ScaledMetric(relativeTo: .title2) private var width = 48.0
    @ScaledMetric(relativeTo: .title2) private var rankSize = 23.0
    @ScaledMetric(relativeTo: .title2) private var suitSize = 27.0

    var body: some View {
        VStack(spacing: 0) {
            Text(card.label).font(.system(size: rankSize, weight: .bold, design: .serif))
            Text(card.suit.glyph).font(.system(size: suitSize))
        }
        .foregroundStyle(card.suit.ink)
        .frame(width: width, height: width * 1.5)
        .background(.ivory, in: RoundedRectangle(cornerRadius: 8))
        .overlay(RoundedRectangle(cornerRadius: 8).stroke(.black.opacity(0.15)))
        .shadow(color: .black.opacity(0.25), radius: 3, y: 3)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(card.spoken)
    }
}

extension ShapeStyle where Self == Color {
    static var ivory: Color { Color(red: 0.98, green: 0.96, blue: 0.89) }
    static var felt: Color { Color(red: 0.035, green: 0.16, blue: 0.13) }
    static var gold: Color { Color(red: 0.91, green: 0.75, blue: 0.42) }
}
