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
    /// The trial layouts (D113) carry the score here as a plate, us then them; a tap opens the score sheet.
    var score: (us: Int, them: Int)? = nil
    var onScore: () -> Void = {}

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
            if let score {
                // Between the home arrow and the rules book.
                SwiftUI.Button(action: onScore) {
                    HStack(spacing: 10) {
                        Text("US").font(.system(.subheadline, design: .serif).weight(.bold))
                        Text("\(score.us)").font(.system(.title2, design: .serif).weight(.bold))
                        Rectangle().fill(Theme.Paper.rule).frame(width: 1.5, height: 20)
                        Text("THEM").font(.system(.subheadline, design: .serif).weight(.bold))
                        Text("\(score.them)").font(.system(.title2, design: .serif).weight(.bold))
                        Image(systemName: "chevron.down").font(.footnote.weight(.bold)).opacity(0.7)
                    }
                    .lineLimit(1).minimumScaleFactor(0.6)
                    .foregroundStyle(Theme.Paper.ink)
                    .padding(.horizontal, 14).frame(minHeight: 38)
                    .background(.ivory, in: Capsule())
                    .overlay(Capsule().stroke(Theme.Paper.rule, lineWidth: 1.5))
                    .shadow(color: .black.opacity(0.35), radius: 3, y: 2)
                        .frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(maxWidth: support.maxX - 44 - 12)
                .position(x: (44 + support.maxX) / 2, y: Theme.Table.topRowHeight / 2)
                .accessibilityLabel("Score: us \(score.us), them \(score.them)")
                .accessibilityHint("Opens the score sheet")
            }
            // On the trial layouts Support lives behind your own face by your hand (D115), and the plate has this room.
            if score == nil {
                SwiftUI.Button(action: onSupport) {
                    Label("Support", systemImage: "questionmark.bubble")
                        .font(.callout).lineLimit(1).minimumScaleFactor(0.75)
                        .frame(width: support.width, height: support.height)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .position(x: support.midX, y: support.midY)
                .accessibilityHint("Rules, scoring and advice; pauses play")
            }
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

