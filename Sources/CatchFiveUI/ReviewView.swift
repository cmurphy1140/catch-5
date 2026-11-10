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
                    Text("You played the strategy's card \(agreed) of \(total) times. Rows marked with a branch show where the standard strategy would have played differently\(difficulty == .easy ? "; the computers are on Easy, so their rows compare them to Standard too" : ""). Standard's choice is a recommendation, not proof that another legal play was wrong.")
                        .font(.footnote)
                }
                ForEach(review.tricks, id: \.number) { trick in
                    Section("Hand \(trick.number) · \(names[trick.winner]) took it") {
                        ForEach(trick.plays, id: \.play.card) { row($0) }
                    }
                }
            }
            .scrollContentBackground(.hidden).background(WoodGrainView().ignoresSafeArea())
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
                    .foregroundStyle(review.agreed ? Color.secondary : Color.primary)
            }
            if !review.agreed {
                Text(describe(review)).font(.footnote).foregroundStyle(.secondary)
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

/// Totals across recorded matches, kept to the simple outcomes (S05): matches, wins and losses, bids made. On the ivory
/// paper of the other reading pages (D134), three large figures first and the plain counts under them.
/// No recent-match list, margin or strategy score for this milestone (S01, S02, S04).
struct StatisticsView: View {
    let stats: Statistics
    let records: [MatchRecord]
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    Image(systemName: "chart.bar.fill").font(.title).foregroundStyle(Theme.Paper.green).accessibilityHidden(true)
                    Text("Statistics").font(.system(.largeTitle, design: .serif).weight(.bold)).accessibilityAddTraits(.isHeader)
                    Spacer()
                    Button(action: onDismiss) {
                        Text("Done").font(.system(.title3, design: .serif).weight(.bold)).foregroundStyle(.ivory)
                            .padding(.horizontal, 18).frame(minHeight: 44)
                            .background(Theme.Paper.green, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                rule
                HStack(alignment: .top, spacing: 8) {
                    figure("\(stats.matches)", "Matches")
                    figure(stats.matches == 0 ? "–" : percent(Double(stats.wins) / Double(stats.matches)), "Won")
                    figure(stats.contractRate.map(percent) ?? "–", "Bids made")
                }
                rule
                if stats.matches == 0 {
                    Text("Finish a match and it will be counted here.").font(.title3).opacity(0.7)
                } else {
                    line("Won", "\(stats.wins)")
                    line("Lost", "\(stats.matches - stats.wins)")
                }
            }
            .padding(20)
            .foregroundStyle(Theme.Paper.ink)
            .paperCard()
            .environment(\.colorScheme, .light)
            .padding(12)
        }
        .background(WoodGrainView().ignoresSafeArea())
    }

    private var rule: some View { Rectangle().fill(Theme.Paper.rule).frame(height: 1.5).accessibilityHidden(true) }

    /// One large figure over its name.
    private func figure(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.system(size: 44, weight: .bold, design: .serif)).foregroundStyle(Theme.Paper.green)
                .lineLimit(1).minimumScaleFactor(0.5)
            Text(label).font(.subheadline.weight(.medium)).opacity(0.75)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .ignore).accessibilityLabel("\(label): \(value)")
    }

    private func line(_ label: String, _ value: String) -> some View {
        HStack { Text(label); Spacer(); Text(value).fontWeight(.semibold) }.font(.title3)
    }
    private func percent(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
}
