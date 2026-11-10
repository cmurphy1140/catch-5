import CatchFive
import SwiftUI

/// The scorecard (N66), at its first size again and lying in the table's bottom-right corner above your hand: a score
/// pad on the table (D94), light tan paper turned a little with its shadow on the wood and no frame, ruled faintly like a
/// notebook page, with a US and a THEM column. When a hand ends each team's new total is handwritten on the next
/// line and the one before it gets a scratch through it, as on paper; nothing moves during a hand. Only the last
/// few lines fit; a tap opens the full sheet (`ScorePanel`) with every hand. It replaces the green rails (D82, D83).
struct Scorecard: View {
    /// One handwritten total, and whether a later one has crossed it out.
    struct Line: Equatable {
        let total: Int
        let struck: Bool
    }

    nonisolated static let columns = ["US", "THEM"]
    /// The handwriting, built into iOS.
    nonisolated static let handwriting = "Marker Felt"
    /// The pad lies a little crooked, as a pad put down by hand does, and casts a soft shadow (D94).
    nonisolated static let tiltDegrees = 2.0
    nonisolated static let shadowRadius = 5.0

    /// `team`'s totals after each finished hand, all but the newest struck.
    nonisolated static func lines(team: Int, history: [HandSummary]) -> [Line] {
        history.enumerated().map { index, hand in Line(total: hand.scores[team], struck: index < history.count - 1) }
    }

    /// The full sheet's names for a team: US and THEM in solo; in pass and play the phone turns, so each names its pair.
    nonisolated static func label(us: Bool, mode: PlayMode, teamNames: String) -> String {
        mode == .solo ? (us ? "US" : "THEM") : teamNames.uppercased()
    }

    /// The pad lies on the table while cards are played (D100). The auction's buttons and the reviewed trick's way back
    /// need that corner, and the hand's result card shows both totals, so it is put away then.
    nonisolated static func liesOnTable(phase: HandPhase, reviewing: Bool) -> Bool {
        phase == .playing && !reviewing
    }

    /// The phone holder's team's lines, then the other team's.
    let us: [Line]
    let them: [Line]
    /// The corner's width, from `TableLayout.cornerWidth(available:)`; the height is `Theme.Table.cornerHeight`.
    let width: Double
    let onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(Self.columns, id: \.self) { column in
                        Text(column).font(.subheadline.weight(.heavy)).frame(maxWidth: .infinity)
                    }
                }
                .frame(height: Theme.Table.scorecardRule)
                HStack(spacing: 0) {
                    column(us)
                    column(them)
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
            .foregroundStyle(Theme.Wood.streakDark)
            .padding(.vertical, 4)
            .frame(width: width, height: Theme.Table.cornerHeight)
            .background { page }
            .rotationEffect(.degrees(Self.tiltDegrees))
            .shadow(color: .black.opacity(0.5), radius: Self.shadowRadius, x: 2, y: 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityLabel("Scorecard: us \(us.last?.total ?? 0), them \(them.last?.total ?? 0)")
        .accessibilityHint("Shows every hand")
    }

    /// The newest lines that fit, oldest at the top.
    private func column(_ lines: [Line]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(lines.suffix(Theme.Table.scorecardLines).enumerated()), id: \.offset) { _, line in
                Text(line.total, format: .number)
                    .font(.custom(Self.handwriting, size: Theme.Table.scorecardNumberSize, relativeTo: .title3))
                    .foregroundStyle(line.struck ? Theme.Wood.dark.opacity(0.75) : Theme.Wood.streakDark)
                    .overlay {
                        if line.struck {
                            Capsule().fill(Theme.Wood.streakDark).frame(height: 2.5).padding(.horizontal, -5)
                                .rotationEffect(.degrees(-12))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: Theme.Table.scorecardRule)
            }
        }
    }

    /// Light tan paper with square corners and the pad's glued edge along the top, a faint blue-free rule under the
    /// heading and every line after, and a line between the columns.
    private var page: some View {
        let shape = RoundedRectangle(cornerRadius: 2, style: .continuous)
        return shape.fill(Theme.Table.cornerFill)
            .overlay(alignment: .top) { Rectangle().fill(Theme.Wood.dark.opacity(0.55)).frame(height: 4) }
            .overlay {
                Canvas { context, size in
                    var rules = Path()
                    var y = 4 + Theme.Table.scorecardRule
                    while y < size.height - 4 {
                        rules.move(to: CGPoint(x: 0, y: y))
                        rules.addLine(to: CGPoint(x: size.width, y: y))
                        y += Theme.Table.scorecardRule
                    }
                    context.stroke(rules, with: .color(Theme.Wood.light.opacity(0.45)), lineWidth: 1)
                    var margin = Path()
                    margin.move(to: CGPoint(x: size.width / 2, y: 6))
                    margin.addLine(to: CGPoint(x: size.width / 2, y: size.height - 6))
                    context.stroke(margin, with: .color(Theme.Wood.light.opacity(0.7)), lineWidth: 1.5)
                }
            }
            .clipShape(shape)
    }
}
