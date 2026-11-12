import CatchFive
import SwiftUI

/// The finished hand on its ivory card, three pages deep: the calm result (R01, R02), then Review hand's two halves,
/// the points and who captured each, and the tricks card by card (R03, R04).
struct HandSummaryView: View {
    enum Page { case summary, points, tricks }

    let match: Match
    let names: [String]
    /// Built once by the model from the same history; nil only before any hand has finished.
    let outcome: HandOutcome?
    let review: HandReview?
    let difficulty: Difficulty
    let describe: (PlayReview) -> String
    let coaching: Bool
    var onReplay: (() -> Void)?
    @State private var page = Page.summary
    /// The trick whose cards are laid out on the Tricks page.
    @State private var openTrick: Int? = 1

    /// The team picked out in green: whoever the hand did more for, the bidders when it did the same for both.
    nonisolated static func teamAhead(bidderTeam: Int, changes: [Int]) -> Int {
        changes[bidderTeam] >= changes[1 - bidderTeam] ? bidderTeam : 1 - bidderTeam
    }

    var body: some View {
        if let summary = match.history.last, let outcome {
            VStack(spacing: 14) {
                if page == .summary { summaryPage(summary, outcome) } else { reviewPage(summary, outcome) }
            }
            .padding(.horizontal, 8).padding(.top, 10).padding(.bottom, 4)
            .foregroundStyle(Theme.Paper.ink)
            .onAppear {
                if ScreenshotStage.name == "review" { page = .points }
                if ScreenshotStage.name == "review-tricks" { page = .tricks }
            }
        }
    }

    // MARK: Summary

    @ViewBuilder private func summaryPage(_ summary: HandSummary, _ outcome: HandOutcome) -> some View {
        RuledLine {
            Text("HAND COMPLETE").font(.system(.subheadline, design: .serif).weight(.bold)).tracking(4)
                .foregroundStyle(Theme.Paper.green)
        }
        if let trump = match.hand.trump {
            Text(trump.glyph).font(.system(size: 38)).foregroundStyle(ink(trump))
                .frame(width: 64, height: 64)
                .overlay(Circle().stroke(Theme.Paper.rule, lineWidth: 2.5))
                .overlay(Circle().stroke(Theme.Paper.rule.opacity(0.5), lineWidth: 1).padding(4))
                .accessibilityHidden(true)
        }
        VStack(spacing: 2) {
            Text(outcome.headline).font(.system(.largeTitle, design: .serif).weight(.bold))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text(bidLine(summary)).font(.title2).opacity(0.6)
        }
        .accessibilityElement(children: .combine)
        trumpLine
        tiles(summary, showsBefore: false)
        VStack(spacing: 0) {
            Divider().overlay(Theme.Paper.ink.opacity(0.2))
            Button { page = .points } label: {
                HStack(spacing: 14) {
                    Image(systemName: "rectangle.portrait.on.rectangle.portrait.angled").font(.title2)
                    Text("Review hand").font(.title3.weight(.medium)).foregroundStyle(Theme.Paper.ink)
                    Spacer()
                    Image(systemName: "chevron.right").font(.title3.weight(.semibold))
                }
                .foregroundStyle(Theme.Paper.green)
                .frame(minHeight: 56).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint("Points and tricks for this hand")
            if let onReplay {
                Divider().overlay(Theme.Paper.ink.opacity(0.2))
                Button("Replay hand", systemImage: "play.rectangle", action: onReplay)
                    .font(.title3.weight(.medium)).foregroundStyle(Theme.Paper.green)
                    .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).buttonStyle(.plain)
                    .accessibilityHint("Every bid, discard, trick and score change, with the house rules")
            }
            Divider().overlay(Theme.Paper.ink.opacity(0.2))
        }
    }

    private func bidLine(_ summary: HandSummary) -> String {
        "\(names[summary.bidder]) bid \(summary.isNineAndOut ? "9 and out" : String(summary.bid))"
    }

    /// Black suits are set in the card's green; red ones keep their red.
    private func ink(_ suit: Suit) -> Color { suit.isRed ? .suitRed : Theme.Paper.green }

    @ViewBuilder private var trumpLine: some View {
        if let trump = match.hand.trump {
            RuledLine {
                HStack(spacing: 6) {
                    Text(trump.glyph).foregroundStyle(ink(trump))
                    Text("\(trump.rawValue.capitalized) trump")
                }
                .font(.title3.weight(.medium))
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(trump.rawValue) trump")
        }
    }

    // MARK: Score tiles

    /// Both teams' totals side by side; the Points page also shows where each started.
    private func tiles(_ summary: HandSummary, showsBefore: Bool) -> some View {
        let before = [0, 1].map { match.history.dropLast().last?.scores[$0] ?? 0 }
        let ahead = Self.teamAhead(bidderTeam: summary.bidder % 2, changes: [0, 1].map { summary.scores[$0] - before[$0] })
        return HStack(spacing: 10) {
            ForEach(0..<2, id: \.self) { team in
                tile(team: team, before: before[team], after: summary.scores[team], ahead: team == ahead, showsBefore: showsBefore)
            }
        }
    }

    private func tile(team: Int, before: Int, after: Int, ahead: Bool, showsBefore: Bool) -> some View {
        let change = after - before
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(spacing: 4) {
            Text("\(names[team]) + \(names[team + 2])").font(.system(.headline, design: .serif))
                .lineLimit(1).minimumScaleFactor(0.6)
            Text("TOTAL SCORE").font(.caption2.weight(.medium)).tracking(2).opacity(0.6)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if showsBefore {
                    Text(before, format: .number).opacity(0.45)
                    Image(systemName: "arrow.right").font(.title3.weight(.semibold)).accessibilityLabel("to")
                }
                Text(after, format: .number)
            }
            .font(.system(size: showsBefore ? 40 : 56, weight: .bold, design: .serif)).monospacedDigit()
            .lineLimit(1).minimumScaleFactor(0.6)
            Text("\(change >= 0 ? "+\(change)" : "\(change)") this hand").font(.subheadline.weight(.medium)).monospacedDigit()
                .lineLimit(1).minimumScaleFactor(0.7)
                .padding(.horizontal, 14).frame(minHeight: 32)
                .foregroundStyle(ahead ? .ivory : Theme.Paper.green)
                .background(ahead ? Theme.Paper.green : Theme.Paper.tan, in: Capsule())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 6).padding(.vertical, 12)
        .background(ahead ? Theme.Paper.wash : .clear, in: shape)
        .overlay(shape.stroke(ahead ? Theme.Paper.green : Theme.Paper.ink.opacity(0.18), lineWidth: ahead ? 1.5 : 1))
        .accessibilityElement(children: .combine)
    }

    // MARK: Review

    @ViewBuilder private func reviewPage(_ summary: HandSummary, _ outcome: HandOutcome) -> some View {
        Button { page = .summary } label: {
            Label("Summary", systemImage: "chevron.left").font(.body.weight(.medium))
                .frame(minHeight: 44).contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.bottom, -14)
        RuledLine { Text("Hand review").font(.system(.title, design: .serif).weight(.bold)).lineLimit(1) }
        PaperSwitch(options: [("Points", Page.points), ("Tricks", Page.tricks)], selection: $page)
        if page == .points { pointsPage(summary, outcome) } else { tricksPage }
    }

    @ViewBuilder private func pointsPage(_ summary: HandSummary, _ outcome: HandOutcome) -> some View {
        let result = summary.result
        HStack(spacing: 8) {
            Image(systemName: summary.contractMade ? "checkmark.circle.fill" : "xmark.circle.fill")
                .foregroundStyle(summary.contractMade ? Theme.Paper.green : .suitRed)
            Text("\(outcome.headline) · \(bidLine(summary))").lineLimit(1).minimumScaleFactor(0.6)
        }
        .font(.system(.title3, design: .serif).weight(.semibold))
        .accessibilityElement(children: .combine)
        trumpLine
        tiles(summary, showsBefore: true)
        VStack(spacing: 0) {
            HStack {
                Text("Hand points")
                Spacer()
                Text("\(result.points[0])–\(result.points[1])").monospacedDigit()
                    .accessibilityLabel("\(result.points[0]) to \(result.points[1])")
            }
            .font(.system(.title2, design: .serif).weight(.bold)).padding(.bottom, 6)
            Rectangle().fill(Theme.Paper.rule).frame(height: 1)
            columns(Text("POINT"), Text("CAPTURED BY"))
                .font(.caption.weight(.medium)).tracking(2).opacity(0.6)
            row("High", team: result.highTeam)
            row("Low", team: result.lowTeam)
            row("Jack", team: result.jackTeam)
            row("Five", pill: "5 points", team: result.fiveTeam)
            row("Game", count: "\(result.gameValues[0])–\(result.gameValues[1])", team: result.gameTeam)
        }
        // The Game row already carries the count; its note stays only when a tie needed the rule to settle it.
        ForEach(result.gameValues[0] == result.gameValues[1] ? outcome.notes : Array(outcome.notes.dropFirst()), id: \.self) { note in
            Text(note).font(.footnote).opacity(0.7).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Two columns that start at the card's edge and at its middle, with a hairline under them.
    private func columns(_ left: some View, _ right: some View) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                left.frame(maxWidth: .infinity, alignment: .leading)
                right.frame(maxWidth: .infinity, alignment: .leading)
            }
            .lineLimit(1).minimumScaleFactor(0.6)
            .padding(.horizontal, 6).frame(minHeight: 40)
            Divider().overlay(Theme.Paper.ink.opacity(0.2))
        }
        .accessibilityElement(children: .combine)
    }

    private func row(_ name: String, pill: String? = nil, count: String? = nil, team: Int?) -> some View {
        columns(
            HStack(spacing: 10) {
                Text(name).font(.title3.weight(.medium))
                if let pill {
                    Text(pill).font(.footnote.weight(.medium)).foregroundStyle(Theme.Paper.green)
                        .padding(.horizontal, 10).frame(minHeight: 24)
                        .background(Theme.Paper.tan, in: Capsule())
                        .overlay(Capsule().stroke(Theme.Paper.rule.opacity(0.7)))
                }
                if let count { Text(count).font(.body).monospacedDigit().opacity(0.5) }
            },
            Text(team.map { "\(names[$0]) + \(names[$0 + 2])" } ?? "Out of play").font(.title3)
        )
    }

    // MARK: Tricks

    @ViewBuilder private var tricksPage: some View {
        trumpLine
        if let review {
            VStack(spacing: 0) {
                ForEach(review.tricks, id: \.number) { trick in
                    trickRow(trick)
                    if openTrick != trick.number { Divider().overlay(Theme.Paper.ink.opacity(0.2)) }
                }
            }
        } else {
            Text("Nothing to review yet.").font(.body).opacity(0.6)
        }
    }

    /// One trick: its number and who took it, and when open the four cards in the order they were played.
    private func trickRow(_ trick: TrickReview) -> some View {
        let open = openTrick == trick.number
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        return VStack(spacing: 10) {
            Button { openTrick = open ? nil : trick.number } label: {
                HStack(spacing: 12) {
                    Text(trick.number, format: .number).font(.system(.subheadline, design: .serif).weight(.bold))
                        .frame(width: 30, height: 30)
                        .background(Theme.Paper.tan, in: Circle())
                        .overlay(Circle().stroke(Theme.Paper.rule, lineWidth: 1.5))
                    Text("Trick \(trick.number)").font(.system(.title3, design: .serif).weight(.bold))
                    Spacer(minLength: 4)
                    Text("\(names[trick.winner]) took it").font(.body)
                    Image(systemName: open ? "chevron.up" : "chevron.right").font(.body.weight(.semibold))
                        .foregroundStyle(Theme.Paper.green).frame(width: 20)
                }
                .lineLimit(1).minimumScaleFactor(0.6)
                .frame(minHeight: 48).contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityHint(open ? "Hides the cards" : "Shows the cards")
            if open {
                HStack(alignment: .top, spacing: 6) {
                    ForEach(trick.plays, id: \.play.card) { reviewed in
                        let won = reviewed.play.seat == trick.winner
                        VStack(spacing: 5) {
                            Text(names[reviewed.play.seat]).font(.subheadline.weight(.medium)).lineLimit(1).minimumScaleFactor(0.6)
                            CardView(card: reviewed.play.card, width: 50, ring: won ? Theme.Paper.green : nil)
                            Text("Took trick").font(.caption.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.6)
                                .foregroundStyle(.ivory)
                                .padding(.horizontal, 8).frame(minHeight: 22)
                                .background(Theme.Paper.green, in: Capsule())
                                .opacity(won ? 1 : 0)
                        }
                        .frame(maxWidth: .infinity)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(names[reviewed.play.seat]), \(reviewed.play.card.name)\(won ? ", took the trick" : "")")
                    }
                }
                // Coaching keeps its say where the standard strategy would have played another card.
                if coaching {
                    ForEach(trick.plays.filter { !$0.agreed }, id: \.play.card) { reviewed in
                        Text("\(names[reviewed.play.seat]): \(describe(reviewed))").font(.footnote).opacity(0.7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, open ? 10 : 6).padding(.bottom, open ? 10 : 0)
        .background(open ? Theme.Paper.wash : .clear, in: shape)
        .overlay(shape.stroke(open ? Theme.Paper.green : .clear, lineWidth: 1.5))
        .padding(.vertical, open ? 4 : 0)
    }
}
