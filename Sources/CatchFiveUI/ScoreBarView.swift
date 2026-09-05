import CatchFive
import SwiftUI

/// The compact bar pinned above the table: title with the hand number, the menu, and both scores.
/// Trump, contract and the dealer live on the table itself (`TableSurface.contractPill`, `HandFanView`).
struct ScoreBarView: View {
    let us: Int
    let them: Int
    let usLabel: String
    let themLabel: String
    let handNumber: Int
    let canUndo: Bool
    let onUndo: () -> Void
    let onScores: () -> Void
    let onSettings: () -> Void
    let onStatistics: () -> Void
    let onTutorial: () -> Void
    let onNewGame: () -> Void
    let onLeave: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Button(action: onLeave) {
                    Image(systemName: "chevron.left").font(.title3).frame(width: 44, height: 44, alignment: .leading)
                }
                .tint(.ivory.opacity(0.7))
                .accessibilityLabel("Back to menu")
                Text("CATCH 5").font(.system(.title3, design: .serif).weight(.bold))
                Text("HAND \(handNumber)").font(.system(.subheadline, design: .monospaced)).opacity(0.7)
                    .padding(.leading, 12)
                    .accessibilityLabel("Hand \(handNumber)")
                Spacer()
                Menu {
                    Button("Undo last action", systemImage: "arrow.uturn.backward", action: onUndo).disabled(!canUndo)
                    Divider()
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
                        Spacer(minLength: 12)
                        team(themLabel, them, .trailing)
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Shows every hand of this match")
        }
    }

    private func team(_ label: String, _ value: Int, _ alignment: HorizontalAlignment) -> some View {
        VStack(alignment: alignment, spacing: 0) {
            Text(label).font(.system(.caption2, design: .monospaced)).opacity(0.7).lineLimit(1).minimumScaleFactor(0.7)
            Text(value, format: .number).font(.system(.title, design: .serif).weight(.semibold)).monospacedDigit()
        }.accessibilityElement(children: .combine)
    }
}
