import CatchFive
import SwiftUI

/// The new player's one-page intro after login: how a hand goes in five steps, with a door to the
/// full tutorial and a way to skip straight to the table.
struct IntroView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var tutorial: TutorialModel
    let onDone: () -> Void
    @State private var showTutorial = false

    static let steps: [(title: String, detail: String, symbol: String)] = [
        ("Deal", "Six cards each. You and the player across from you are partners.", "rectangle.stack"),
        ("Bid", "Promise how many of the nine points your team will take, 2 to 9. Highest bid names trump.", "hand.raised"),
        ("Trump", "Non-trumps go back and you draw up to six. Trump beats every other suit.", "suit.heart.fill"),
        ("Tricks", "Follow suit if you can. Highest trump wins, otherwise the highest card of the suit led.", "square.stack.3d.up"),
        ("Score", "High, Low, Jack and Game are a point each; the trump Five is worth five. First team to 25 wins.", "star"),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("CATCH 5").font(.system(.largeTitle, design: .serif).weight(.bold))
                    Text("HOW A HAND GOES").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.7)
                }
                .padding(.top, 32)

                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(Self.steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                ZStack {
                                    Circle().fill(Theme.Wood.inlay).frame(width: 36, height: 36)
                                    Circle().stroke(.gold.opacity(0.7), lineWidth: 1).frame(width: 36, height: 36)
                                    Image(systemName: step.symbol).font(.subheadline).foregroundStyle(.gold)
                                }
                                if index < Self.steps.count - 1 {
                                    Rectangle().fill(.ivory.opacity(0.18)).frame(width: 1).frame(maxHeight: .infinity)
                                }
                            }
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(index + 1) · \(step.title)").font(.headline)
                                Text(step.detail).font(.subheadline).opacity(0.8).fixedSize(horizontal: false, vertical: true)
                            }
                            .padding(.bottom, index < Self.steps.count - 1 ? 18 : 0)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(18)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                VStack(spacing: 10) {
                    Button { showTutorial = true } label: {
                        Text("Learn the game").frame(maxWidth: .infinity).frame(minHeight: 44)
                    }
                    .buttonStyle(.bordered).tint(.ivory.opacity(0.8))
                    Button(action: onDone) {
                        Text("Deal me in").font(.headline).frame(maxWidth: .infinity).frame(minHeight: 50)
                    }
                    .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
                }
            }
            .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
        .foregroundStyle(.ivory)
        .background(LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .tutorialCover(isPresented: $showTutorial) { TutorialView(model: tutorial, isIntro: true) { showTutorial = false; onDone() } }
    }
}

private extension View {
    /// Full screen on the phone; the macOS test build has no full-screen cover, so a sheet stands in.
    func tutorialCover<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        return fullScreenCover(isPresented: isPresented, content: content)
        #else
        return sheet(isPresented: isPresented, content: content)
        #endif
    }
}
