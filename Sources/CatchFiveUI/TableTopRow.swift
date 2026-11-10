import SwiftUI

/// Home at the leading edge, a portrait rules book at the safe trailing edge, and Support beside the book (D105, D112).
struct TableTopRow: View {
    struct Button: Equatable {
        let title: String
        let symbol: String
        var showsTitle = true
    }
    nonisolated static let home = Button(title: "Home", symbol: "arrow.backward", showsTitle: false)
    nonisolated static let rules = Button(title: "Rules", symbol: "book")
    let onHome: () -> Void
    let onRules: () -> Void
    var onSupport: () -> Void = {}

    var body: some View {
        GeometryReader { geometry in
            let book = TableLayout.bookFrame(available: geometry.size.width)
            SwiftUI.Button(action: onHome) {
                Image(systemName: Self.home.symbol)
                    .font(.system(size: Theme.Table.homeArrowSize, weight: .black))
                    .modifier(Carved(depth: Carving.depth(size: Theme.Table.homeArrowSize)))
                    .frame(width: 44, height: 44).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Self.home.title)
            .accessibilityHint("Back to the main menu; your game is saved")
            .position(x: 22, y: Theme.Table.topRowHeight / 2)
            let support = TableLayout.supportFrame(available: geometry.size.width)
            SwiftUI.Button(action: onSupport) {
                Label("Support", systemImage: "questionmark.bubble")
                    .font(.callout).lineLimit(1).minimumScaleFactor(0.75)
                    .frame(width: support.width, height: support.height)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .position(x: support.midX, y: support.midY)
            .accessibilityHint("Rules, scoring and advice; pauses play")
            SwiftUI.Button(action: onRules) { RulesBook() }
                .buttonStyle(BookPressStyle())
                .frame(width: book.width, height: book.height)
                .position(x: book.midX, y: book.midY)
                .accessibilityLabel(Self.rules.title)
                .accessibilityHint("Opens the rules")
        }
        .frame(height: Theme.Table.topRowHeight)
        .zIndex(2)
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
    }
}
