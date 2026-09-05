import CatchFive
import SwiftUI

/// Every play of the finished hand next to what the standard strategy would have done.
struct ReviewView: View {
    let review: HandReview
    let names: [String]
    let difficulty: Difficulty
    /// Words one reviewed play; shared with tap-to-explain so the two never differ.
    let describe: (PlayReview) -> String
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                let (agreed, total) = review.agreement(forSeat: 0)
                Section {
                    Text("You played the strategy's card \(agreed) of \(total) times. Rows in gold show where the standard strategy would have played differently\(difficulty == .easy ? "; the computers are on Easy, so their rows compare them to Standard too" : "").")
                        .font(.footnote)
                }
                ForEach(review.tricks, id: \.number) { trick in
                    Section("Trick \(trick.number) · \(names[trick.winner]) took it") {
                        ForEach(trick.plays, id: \.play.card) { row($0) }
                    }
                }
            }
            .navigationTitle("Hand review")
            .toolbar { Button("Done", action: onDismiss) }
        }
    }

    @ViewBuilder private func row(_ review: PlayReview) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(names[review.play.seat]).font(.subheadline.weight(.semibold))
                Spacer()
                Text(review.play.card.name).font(.subheadline)
                Image(systemName: review.agreed ? "checkmark" : "arrow.triangle.branch")
                    .foregroundStyle(review.agreed ? Color.secondary : Color.gold)
            }
            if !review.agreed {
                Text(describe(review)).font(.footnote).foregroundStyle(.gold)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

/// Shown if a review could not be built, so the sheet always has content and a Done button.
struct ReviewUnavailableView: View {
    let onDismiss: () -> Void
    var body: some View {
        NavigationStack {
            Text("Nothing to review yet.").foregroundStyle(.secondary)
                .navigationTitle("Hand review")
                .toolbar { Button("Done", action: onDismiss) }
        }
    }
}

/// Every hand of the match so far.
struct ScoreboardView: View {
    let history: [HandSummary]
    let names: [String]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                if history.isEmpty { Text("No hands scored yet.").foregroundStyle(.secondary) }
                ForEach(history, id: \.number) { hand in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hand \(hand.number)").font(.subheadline.weight(.semibold))
                            Text("\(names[hand.bidder]) bid \(hand.isNineAndOut ? "9 and out" : String(hand.bid)), \(hand.contractMade ? "made" : "set") · points \(hand.result.points[0])–\(hand.result.points[1])")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text("\(hand.scores[0]) – \(hand.scores[1])").font(.headline.monospacedDigit())
                    }
                }
            }
            .navigationTitle("Scoreboard")
            .toolbar { Button("Done", action: onDismiss) }
        }
    }
}

/// Totals across recorded matches, newest first.
struct StatisticsView: View {
    let stats: Statistics
    let records: [MatchRecord]
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            List {
                Section("All matches") {
                    line("Matches", "\(stats.matches)")
                    line("Won", stats.matches == 0 ? "–" : "\(stats.wins) (\(percent(Double(stats.wins) / Double(stats.matches))))")
                    line("Average margin", stats.matches == 0 ? "–" : String(format: "%+.1f", stats.averageMargin))
                    line("Contracts made", stats.contractRate.map(percent) ?? "–")
                    line("Played the strategy's card", stats.agreementRate.map(percent) ?? "–")
                }
                Section("Recent") {
                    if records.isEmpty { Text("Finish a match to see it here.").foregroundStyle(.secondary) }
                    ForEach(records.reversed()) { record in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(record.humanWon ? "Won" : "Lost").font(.subheadline.weight(.semibold))
                                Text("\(record.date.formatted(date: .abbreviated, time: .shortened)) · \(record.hands) hands · \(record.difficulty.rawValue)")
                                    .font(.footnote).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text("\(record.scores[0]) – \(record.scores[1])").font(.headline.monospacedDigit())
                        }
                    }
                }
            }
            .navigationTitle("Statistics")
            .toolbar { Button("Done", action: onDismiss) }
        }
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).foregroundStyle(.secondary) }
    }
    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}
