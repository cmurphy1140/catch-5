import SwiftUI

/// The play page (D133), reached from the opening page's Play: the top half holds the ways into a game, New game on the
/// left and Back to the table on the right, written on the wood; the bottom half is one fixed sheet of paper holding the
/// How to play lessons, with arrows to step between them. The sheet never grows: a long lesson scrolls inside it.
struct PlayPage: View {
    let buttons: [MainMenuView.HomeButton]
    @ObservedObject var tutorial: TutorialModel
    let perform: (MainMenuView.HomeButton.Action) -> Void
    let onClose: () -> Void
    /// The cloth, when the build carries the scene that sits on it (D162); nil keeps the wood.
    var colours: Settings.TableColours?
    /// Opens the helper; nil leaves the prompt box off the page.
    var onAsk: (() -> Void)?
    var onPractice: (() -> Void)?
    var onSavedHands: (() -> Void)?

    private var scene: Bool { colours != nil && HomeScene.carried }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Button("Back", systemImage: "chevron.left", action: onClose)
                    .labelStyle(.iconOnly).font(.title2.weight(.semibold)).buttonStyle(.plain)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: 14) {
                    // Side by side at their own widths, so "Back to the table" stays on one line; halves when that is too wide.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 20) { gameButtons.fixedSize(horizontal: true, vertical: false) }
                        HStack(spacing: 20) { gameButtons }
                    }
                    if onPractice != nil || onSavedHands != nil {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 20) { learningButtons }
                            VStack(spacing: 0) { learningButtons }
                        }
                    }
                    if let onAsk { promptBox(onAsk) }
                }
                .padding(.horizontal, 8).padding(.top, scene ? 4 : 0)
                .frame(maxHeight: scene ? nil : .infinity, alignment: .center)
                if scene {
                    // The three of them sit at the sheet's top edge, as they sat at the table's (D162), in the room the
                    // buttons leave: the scene shrinks to fit that room rather than standing on the prompt box.
                    GeometryReader { room in
                        let width = min((geo.size.width - 32) * 0.88, max(0, room.size.height - Self.sceneGap + Self.sceneTuck) / 0.54)
                        HomeScene(width: width).offset(y: Self.sceneTuck)
                            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                    }
                }
                lessons.frame(height: geo.size.height * 0.52)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .foregroundStyle(.ivory)
        .background { if scene, let colours { HomeFelt(colours: colours) } else { WoodGrainView().ignoresSafeArea() } }
    }

    /// How far the scene's feet tuck behind the sheet, and the clear air kept under the prompt box.
    private static let sceneTuck = 10.0, sceneGap = 8.0

    // New game first, so it is on the left whether or not a game is saved.
    private var gameButtons: some View {
        ForEach(buttons.sorted { $0.action == .newGame && $1.action != .newGame }, id: \.title) { button in
            Button { perform(button.action) } label: {
                Label(button.title, systemImage: button.action == .newGame ? "plus.square" : "arrow.right")
            }
            .buttonStyle(WoodWritingButtonStyle(size: onAsk == nil ? 28 : 22))
        }
    }

    @ViewBuilder private var learningButtons: some View {
        if let onPractice {
            Button("Practice", systemImage: "graduationcap", action: onPractice)
                .font(.system(.headline, design: .serif)).frame(minHeight: 44).buttonStyle(.plain)
        }
        if let onSavedHands {
            Button("Saved hands", systemImage: "clock.arrow.circlepath", action: onSavedHands)
                .font(.system(.headline, design: .serif)).frame(minHeight: 44).buttonStyle(.plain)
        }
    }

    private var lessons: some View {
        VStack(spacing: 10) {
            HStack {
                step("chevron.left", "Previous lesson", enabled: tutorial.lesson > 0) { tutorial.back() }
                VStack(spacing: 2) {
                    Text("HOW TO PLAY · \(tutorial.lesson + 1) OF \(TutorialModel.lessonCount)")
                        .font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Theme.Paper.green)
                    Text(TutorialModel.titles[tutorial.lesson]).font(.system(.title2, design: .serif).weight(.bold))
                        .accessibilityAddTraits(.isHeader)
                }
                .frame(maxWidth: .infinity)
                step("chevron.right", "Next lesson", enabled: !tutorial.isLastLesson) { tutorial.next() }
            }
            // The lesson fades out at the sheet's bottom edge, so what scrolls on below it is not cut by a hard line.
            ScrollView { TutorialLesson(model: tutorial).padding(.bottom, 24) }.id(tutorial.lesson)
                .mask(LinearGradient(stops: [.init(color: .black, location: 0.94), .init(color: .clear, location: 1)],
                                     startPoint: .top, endPoint: .bottom))
        }
        .padding(14)
        .foregroundStyle(Theme.Paper.ink).tint(Theme.Paper.green)
        .paperCard()
        .environment(\.colorScheme, .light)
    }

    /// The helper's prompt box (D163): a wide pane of frosted glass that reads like a chat's text field and opens the
    /// helper when touched.
    private func promptBox(_ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "sparkles").font(.body.weight(.semibold)).accessibilityHidden(true)
                Text("Ask anything").font(.system(.title3, design: .rounded))
                Spacer(minLength: 0)
                Image(systemName: "arrow.up.circle.fill").font(.system(size: 30)).accessibilityHidden(true)
            }
            .foregroundStyle(.ivory.opacity(0.92))
            .padding(.leading, 18).padding(.trailing, 10).frame(height: 54)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().stroke(.ivory.opacity(0.28), lineWidth: 1))
            .shadow(color: .black.opacity(0.3), radius: 6, y: 3)
            .environment(\.colorScheme, .dark)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Ask anything").accessibilityHint("Opens a chat with the game's helper")
    }

    private func step(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(label, systemImage: symbol, action: action)
            .labelStyle(.iconOnly).font(.title2.weight(.bold)).buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.25).disabled(!enabled)
    }
}
