import SwiftUI

/// The slim row across the top of the table: Home on the left keeps the saved match,
/// and Support beside the closed rules book opens help and pauses play while its sheet is up.
/// The book still opens the rules (D94); the carved back arrow returns to the main menu (D95).
struct TableTopRow: View {
    struct Button: Equatable {
        let title: String
        let symbol: String
        /// The title is printed on the control; when false it is only VoiceOver's label (D95).
        var showsTitle = true
    }

    nonisolated static let home = Button(title: "Home", symbol: "arrow.backward", showsTitle: false)
    nonisolated static let rules = Button(title: "Rules", symbol: "book")

    let onHome: () -> Void
    let onRules: () -> Void
    var onSupport: () -> Void = {}

    var body: some View {
        HStack(spacing: 8) {
            item(Self.home, hint: "Back to the main menu; your game is saved", action: onHome) {
                // A back arrow alone, cut into the wood (D95): no house, no word, no pill.
                Image(systemName: Self.home.symbol)
                    .font(.system(size: Theme.Table.homeArrowSize, weight: .black))
                    .modifier(Carved(depth: Carving.depth(size: Theme.Table.homeArrowSize)))
            }
            Spacer(minLength: 0)
            SwiftUI.Button(action: onSupport) {
                Label("Support", systemImage: "questionmark.bubble")
                    .font(.callout)
                    .padding(.horizontal, 6)
                    .frame(minHeight: Theme.Table.topRowHeight)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Rules, scoring and advice; pauses play")
            SwiftUI.Button(action: onRules) { RulesBook() }
                .buttonStyle(BookPressStyle())
                // The book is taller than the row (D100): it overhangs above and below rather than pushing the table down.
                .frame(height: Theme.Table.topRowHeight)
                .accessibilityLabel(Self.rules.title)
                .accessibilityHint("Opens the rules")
        }
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
    }

    /// One control of the row: whatever lies on the table there, inside a thumb-tall hit area.
    private func item(_ button: Button, hint: String, action: @escaping () -> Void, @ViewBuilder label: () -> some View) -> some View {
        SwiftUI.Button(action: action) {
            label()
                .padding(.horizontal, 6)
                .frame(minWidth: Theme.Table.topRowHeight, minHeight: Theme.Table.topRowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(button.title)
        .accessibilityHint(hint)
    }
}
