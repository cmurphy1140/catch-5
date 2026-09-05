import CatchFive
import SwiftUI

/// The compact bar pinned above the table: title and menu, both scores, trump and contract, hand number.
struct ScoreBarView: View {
    let us: Int
    let them: Int
    let usLabel: String
    let themLabel: String
    let trump: Suit?
    let contract: String?
    let handNumber: Int
    let youDeal: Bool
    let onScores: () -> Void
    let onSettings: () -> Void
    let onStatistics: () -> Void
    let onTutorial: () -> Void
    let onNewGame: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text("CATCH 5").font(.system(.title3, design: .serif).weight(.bold))
                Spacer()
                Menu {
                    Button("Settings", systemImage: "gearshape", action: onSettings)
                    Button("Statistics", systemImage: "chart.bar", action: onStatistics)
                    Button("How to play", systemImage: "book", action: onTutorial)
                    Divider()
                    Button("Start a new game", systemImage: "arrow.counterclockwise", role: .destructive, action: onNewGame)
                } label: {
                    Image(systemName: "gearshape").font(.title3).frame(width: 44, height: 44, alignment: .trailing)
                }
                .tint(.ivory.opacity(0.7))
                .accessibilityLabel("Menu")
            }
            Button(action: onScores) {
                VStack(spacing: 2) {
                    HStack(alignment: .firstTextBaseline) {
                        team(usLabel, us, .leading)
                        Spacer()
                        team(themLabel, them, .trailing)
                    }
                    HStack {
                        Text(trumpLine).foregroundStyle(.gold)
                        Spacer()
                        Text("HAND \(handNumber)\(youDeal ? " · YOU DEAL" : "")").opacity(0.7)
                    }.font(.system(.caption, design: .monospaced))
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows every hand of this match")
        }
    }

    private var trumpLine: String {
        let base = trump.map { "\($0.glyph) TRUMP" } ?? "— TRUMP"
        return contract.map { "\(base) · \($0.uppercased())" } ?? base
    }

    private func team(_ label: String, _ value: Int, _ alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(label).font(.system(.caption2, design: .monospaced)).opacity(0.7)
            Text(value, format: .number).font(.system(.title, design: .serif).weight(.semibold)).monospacedDigit()
        }.accessibilityElement(children: .combine)
    }
}
