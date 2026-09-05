import CatchFive
import SwiftUI

struct HandSummaryView: View {
    let match: Match
    let names: [String]
    var body: some View {
        if let summary = match.history.last {
            VStack(spacing: 8) {
                Text("HAND POINTS  \(summary.result.points[0]) – \(summary.result.points[1])").font(.headline)
                row("High", team: summary.result.highTeam)
                row("Low", team: summary.result.lowTeam)
                row("Jack", team: summary.result.jackTeam)
                row("Five · 5 points", team: summary.result.fiveTeam)
                row("Game · \(summary.result.gameValues[0])–\(summary.result.gameValues[1])", team: summary.result.gameTeam)
                Text("\(names[summary.bidder]) bid \(summary.isNineAndOut ? "9 and out" : String(summary.bid))")
                    .font(.caption).opacity(0.6)
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
