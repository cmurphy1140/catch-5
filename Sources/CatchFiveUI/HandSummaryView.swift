import CatchFive
import SwiftUI

struct HandSummaryView: View {
    let match: Match
    let names: [String]
    /// Built once by the model from the same history; nil only before any hand has finished.
    let outcome: HandOutcome?
    var body: some View {
        if let summary = match.history.last, let outcome {
            VStack(spacing: 8) {
                // The verdict first, in gold as a key result, then what it did to the score.
                Text(outcome.headline).font(.system(.title3, design: .serif).weight(.semibold)).foregroundStyle(.gold)
                VStack(spacing: 2) {
                    Text(outcome.bidderLine)
                    Text(outcome.defenderLine)
                }
                .font(.footnote).multilineTextAlignment(.center).opacity(0.9)
                .accessibilityElement(children: .combine)
                Divider().overlay(.ivory.opacity(0.15)).padding(.vertical, 2)
                Text("HAND POINTS  \(summary.result.points[0]) – \(summary.result.points[1])").font(.headline)
                row("High", team: summary.result.highTeam)
                row("Low", team: summary.result.lowTeam)
                row("Jack", team: summary.result.jackTeam)
                row("Five · 5 points", team: summary.result.fiveTeam)
                row("Game · \(summary.result.gameValues[0])–\(summary.result.gameValues[1])", team: summary.result.gameTeam)
                ForEach(outcome.notes, id: \.self) { note in
                    Text(note).font(.caption).opacity(0.75).multilineTextAlignment(.center)
                }
            }.padding(16).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 16))
        }
    }
    private func row(_ name: String, team: Int?) -> some View {
        HStack {
            Text(name)
            Spacer()
            Text(team.map { $0 == 0 ? "Your team" : "\(names[1]) + \(names[3])" } ?? "Out of play")
        }.font(.caption)
    }
}
