import SwiftUI

/// The play page (D133), reached from the opening page's Play: the top half holds the ways into a game, New game on the
/// left and Back to the table on the right, written on the wood; the bottom half is one fixed sheet of paper holding the
/// How to play lessons, with arrows to step between them. The sheet never grows: a long lesson scrolls inside it.
struct PlayPage: View {
    let buttons: [MainMenuView.HomeButton]
    @ObservedObject var tutorial: TutorialModel
    let perform: (MainMenuView.HomeButton.Action) -> Void
    let onClose: () -> Void

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Button("Back", systemImage: "chevron.left", action: onClose)
                    .labelStyle(.iconOnly).font(.title2.weight(.semibold)).buttonStyle(.plain)
                    .shadow(color: .black.opacity(0.5), radius: 2, y: 1)
                    .frame(width: 44, height: 44).contentShape(Rectangle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                HStack(spacing: 20) {
                    // New game first, so it is on the left whether or not a game is saved.
                    ForEach(buttons.sorted { $0.action == .newGame && $1.action != .newGame }, id: \.title) { button in
                        Button { perform(button.action) } label: {
                            Label(button.title, systemImage: button.action == .newGame ? "plus.square" : "arrow.right")
                        }
                        .buttonStyle(WoodWritingButtonStyle(size: 28))
                    }
                }
                .padding(.horizontal, 8).frame(maxHeight: .infinity)
                lessons.frame(height: geo.size.height * 0.54)
            }
            .padding(.horizontal, 16).padding(.bottom, 8)
        }
        .foregroundStyle(.ivory)
        .background(WoodGrainView().ignoresSafeArea())
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
            ScrollView { TutorialLesson(model: tutorial).padding(.bottom, 8) }.id(tutorial.lesson)
        }
        .padding(14)
        .foregroundStyle(Theme.Paper.ink).tint(Theme.Paper.green)
        .paperCard()
        .environment(\.colorScheme, .light)
    }

    private func step(_ symbol: String, _ label: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        Button(label, systemImage: symbol, action: action)
            .labelStyle(.iconOnly).font(.title2.weight(.bold)).buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
            .frame(width: 44, height: 44).contentShape(Rectangle())
            .opacity(enabled ? 1 : 0.25).disabled(!enabled)
    }
}
