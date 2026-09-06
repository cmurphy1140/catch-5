import CatchFive
import SwiftUI

/// The bar pinned above the table, one row (spec R1): the way home, a score chip that opens the score
/// sheet, the contract chip once bidding has resolved, and the menu. Nothing else lives up here; the
/// hand number is on the score sheet, the seat to act is ringed at the table, and the dealer badge sits
/// on the hand's label.
struct ScoreBarView: View {
    /// What the contract chip shows: the bid and who holds it, plus trump once it is named.
    struct Contract: Equatable {
        let trump: Suit?
        let bid: Int
        let isNineAndOut: Bool
        let bidder: String
    }

    let us: Int
    let them: Int
    let usLabel: String
    let themLabel: String
    let contract: Contract?
    let canUndo: Bool
    let onUndo: () -> Void
    let onScores: () -> Void
    let onSettings: () -> Void
    let onStatistics: () -> Void
    let onTutorial: () -> Void
    let onNewGame: () -> Void
    let onLeave: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            // Chevron and word, no plate (spec R16): the way back to the welcome card reads as a button
            // because it says where it goes, not because it is boxed.
            Button(action: onLeave) {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.left").font(.subheadline.weight(.bold))
                    Text("Home").font(.subheadline.weight(.semibold))
                }
                .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Home")
            .accessibilityHint("Shows the welcome card: continue this game, start a new match, or open Settings")

            Button(action: onScores) {
                HStack(spacing: 4) {
                    Text("Us").opacity(0.7)
                    Text(us, format: .number).font(.system(.title3, design: .serif).weight(.semibold))
                    Text("·").opacity(0.5)
                    Text("Them").opacity(0.7)
                    Text(them, format: .number).font(.system(.title3, design: .serif).weight(.semibold))
                }
                .font(.subheadline.weight(.semibold)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(usLabel) \(us), \(themLabel) \(them)")
            .accessibilityHint("Shows every hand of this match")

            Spacer(minLength: 4)
            if let contract { contractChip(contract) }
            Spacer(minLength: 4)

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
                    .shadow(color: .black.opacity(0.35), radius: 1, y: 1)
            }
            .tint(.ivory)
            .accessibilityLabel("Menu")
        }
        .foregroundStyle(.ivory)
    }

    /// "♣ 3 — Otto" in gold (rule 2), the suit in its own colour; "9 and out" spelled out.
    private func contractChip(_ contract: Contract) -> some View {
        HStack(spacing: 5) {
            if let trump = contract.trump {
                Text(trump.glyph).foregroundStyle(trump.isRed ? Color.suitRed : .ivory)
            }
            Text(contract.isNineAndOut ? "9 and out" : String(contract.bid))
            Text("—").opacity(0.6)
            Text(contract.bidder)
        }
        .font(.system(.subheadline, design: .serif).weight(.semibold))
        .foregroundStyle(.gold)
        .lineLimit(1).minimumScaleFactor(0.7)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Contract: \(contract.bidder) bid \(contract.isNineAndOut ? "9 and out" : String(contract.bid))\(contract.trump.map { ", \($0.rawValue) trump" } ?? "")")
    }
}
