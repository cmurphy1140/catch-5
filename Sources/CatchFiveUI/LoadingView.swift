import CatchFive
import SwiftUI

/// The opening moment (D135): twelve cards are dealt round the table from a deck in the middle, three to a seat as in
/// the game, then the last card lifts, turns over as the five of hearts, and the title comes up under it. A tap skips
/// it; under Reduce Motion the five and the title simply show, then go.
struct LoadingView: View {
    let onDone: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dealt = false
    @State private var edgeOn = false
    @State private var faceUp = false
    @State private var titled = false

    /// How long one card waits behind the one before it.
    static let stagger = 0.055
    static let cards = 12

    var body: some View {
        ZStack {
            WoodGrainView().ignoresSafeArea()
            ForEach(0..<Self.cards, id: \.self) { index in
                let seat = index % 4, round = index / 4
                CardBackView(width: 54)
                    .rotationEffect(.degrees(dealt ? Double(seat) * 90 + Double(round - 1) * 13 : 0))
                    .offset(dealt ? Self.landing(seat: seat, round: round) : .zero)
                    .opacity(titled ? 0 : 1)
                    .animation(.spring(duration: 0.42, bounce: 0.18).delay(Double(index) * Self.stagger), value: dealt)
            }
            VStack(spacing: 22) {
                Group {
                    if faceUp {
                        // The face alone is only pips; it gets the card's paper here, as `CardView` gives it.
                        CardFace(card: Card(.hearts, .five), width: 104)
                            .frame(width: 104, height: 104 * Theme.Card.ratio)
                            .background(CardFace.paper, in: RoundedRectangle(cornerRadius: Theme.Card.radius(width: 104), style: .continuous))
                    } else { CardBackView(width: 104) }
                }
                // Turned by its edge: it narrows to nothing, changes face, and widens again.
                .scaleEffect(x: edgeOn ? 0.03 : 1)
                .scaleEffect(faceUp ? 1.12 : 1)
                .shadow(color: .black.opacity(0.4), radius: faceUp ? 14 : 4, y: faceUp ? 10 : 2)
                Text("Catch 5").font(.system(size: 44, weight: .bold, design: .serif)).foregroundStyle(.ivory)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .opacity(titled ? 1 : 0).offset(y: titled ? 0 : 10)
            }
            .offset(y: 30) // the title sits under the card without pushing it off the middle
        }
        .contentShape(Rectangle())
        .onTapGesture { onDone() }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Catch 5")
        .accessibilityAddTraits(.isButton)
        .accessibilityHint("Opens the game")
        .task {
            if reduceMotion {
                faceUp = true; titled = true
                try? await Task.sleep(for: .seconds(0.9))
            } else {
                dealt = true
                try? await Task.sleep(for: .seconds(Double(Self.cards) * Self.stagger + 0.4))
                withAnimation(.easeIn(duration: 0.16)) { edgeOn = true }
                try? await Task.sleep(for: .seconds(0.16))
                faceUp = true
                withAnimation(.spring(duration: 0.3, bounce: 0.3)) { edgeOn = false }
                try? await Task.sleep(for: .seconds(0.3))
                withAnimation(.easeOut(duration: 0.45)) { titled = true }
                try? await Task.sleep(for: .seconds(0.95))
            }
            if !Task.isCancelled { onDone() }
        }
    }

    /// Where a dealt card comes to rest: its seat's side of the table, the three of a seat fanned a little apart.
    static func landing(seat: Int, round: Int) -> CGSize {
        let spread = Double(round - 1) * 20
        switch seat {
        case 0: return CGSize(width: spread, height: -250)
        case 1: return CGSize(width: 140, height: spread)
        case 2: return CGSize(width: -spread, height: 270)
        default: return CGSize(width: -140, height: -spread)
        }
    }
}
