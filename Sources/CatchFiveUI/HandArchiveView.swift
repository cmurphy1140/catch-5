import CatchFive
import SwiftUI

struct HandArchiveView: View {
    let listing: HandArchiveListing
    let error: String?
    @Binding var query: String
    var isLoading = false
    let onSelect: (ArchivedHand) -> Void
    let onLoadMore: () -> Void
    let onRetry: () -> Void
    let onClose: () -> Void

    var body: some View {
        LearningPage(title: "Saved hands", onClose: onClose) {
            TextField("Search names, trump or contract", text: $query)
                .textFieldStyle(.roundedBorder).frame(minHeight: 44)
                .accessibilityLabel("Search saved hands")
            if let error {
                VStack(alignment: .leading, spacing: 8) {
                    Text(error).fixedSize(horizontal: false, vertical: true)
                    Button("Try saving and loading again", action: onRetry)
                        .frame(minHeight: 44).buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
                }
            }
            if !listing.unreadableFiles.isEmpty {
                Text("\(listing.unreadableFiles.count) saved \(listing.unreadableFiles.count == 1 ? "hand could" : "hands could") not be read. The files are kept, and other hands are still available.")
                    .font(.subheadline)
            }
            if isLoading {
                ProgressView("Loading saved hands…").frame(maxWidth: .infinity, minHeight: 60)
            } else if listing.entries.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text(emptyTitle)
                        .font(.system(.title2, design: .serif).weight(.semibold))
                    Text(emptyDetail).font(.subheadline)
                }
            } else {
                VStack(spacing: 0) {
                    ForEach(listing.entries) { entry in
                        Button { onSelect(entry) } label: { row(entry) }
                            .buttonStyle(.plain)
                        Divider().overlay(Theme.Paper.rule.opacity(0.5))
                    }
                }
            }
            if listing.hasMore && !isLoading {
                Button("Load more hands", action: onLoadMore).buttonStyle(PaperSecondaryButtonStyle())
            }
            Text("Saved hands belong to this player. Practice never adds to this collection.")
                .font(.footnote).foregroundStyle(Theme.Paper.ink.opacity(0.75))
        }
    }

    private var emptyTitle: String {
        if error != nil || !listing.unreadableFiles.isEmpty {
            return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                ? "No readable saved hands" : "No readable matching hands"
        }
        return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Your next hand starts the collection." : "No saved hands match."
    }

    private var emptyDetail: String {
        if error != nil || !listing.unreadableFiles.isEmpty {
            return "Try again to load your collection. Saved files are kept; your current game is safe."
        }
        return query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? "Completed real hands save here. Older match totals do not contain the cards needed for a replay."
            : "Try a player's name, clubs, 9 and out, or a hand number."
    }

    private func row(_ entry: ArchivedHand) -> some View {
        let labels = LearningSeatLabels(names: entry.names, mode: entry.mode)
        return VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Hand \(entry.handNumber) · \(entry.isNineAndOut ? "9 and out" : "Bid \(entry.bid)")")
                    .font(.system(.headline, design: .serif)).foregroundStyle(Theme.Paper.green)
                Spacer(minLength: 4)
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(Theme.Paper.green)
            }
            Text("\(entry.trump.glyph) \(entry.trump.rawValue.capitalized) trump · \(labels.name(entry.bidder))")
                .font(.subheadline).foregroundStyle(entry.trump.isRed ? Color.suitRed : Theme.Paper.ink)
            Text("\(labels.team(0)): \(entry.before[0]) → \(entry.after[0]) · \(labels.team(1)): \(entry.before[1]) → \(entry.after[1])")
                .font(.subheadline).foregroundStyle(Theme.Paper.ink)
            if let winner = entry.winner {
                Text("\(labels.teamSubject(winner)) won the match").font(.subheadline).foregroundStyle(Theme.Paper.ink)
            }
            Text("Saved \(entry.savedAt.formatted(date: .abbreviated, time: .shortened))")
                .font(.caption).foregroundStyle(Theme.Paper.ink.opacity(0.75))
            if entry.recovered {
                Text("Recovered from this game's log using current table names; original played date is unknown.")
                    .font(.caption).foregroundStyle(Theme.Paper.ink.opacity(0.75))
            }
        }
        .multilineTextAlignment(.leading)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .padding(.vertical, 14).contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
