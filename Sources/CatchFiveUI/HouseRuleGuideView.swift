import CatchFive
import SwiftUI

/// The reading surfaces share one sheet of paper, with the existing navigation stack outside it.
struct LearningPage<Content: View>: View {
    let title: String
    let onClose: () -> Void
    @ViewBuilder let content: Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) { content }
                .font(.system(.body, design: .serif))
                .foregroundStyle(Theme.Paper.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .paperCard()
                .padding(12)
        }
        .background(WoodGrainView().ignoresSafeArea())
        .navigationTitle(title)
        .toolbar {
            Button("Done", action: onClose)
                .frame(minWidth: 44, minHeight: 44)
                .foregroundStyle(.ivory)
        }
    }
}

struct LearningRuleLinks: View {
    let rules: [ReplayRule]
    let onRule: (ReplayRule) -> Void

    private var uniqueRules: [ReplayRule] {
        var seen: Set<String> = []
        return rules.filter { seen.insert(HouseRuleGuide.entry(for: $0).id).inserted }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if !rules.isEmpty {
                Text("House rules").font(.headline).accessibilityAddTraits(.isHeader)
                ForEach(uniqueRules, id: \.rawValue) { rule in
                    Button { onRule(rule) } label: {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(HouseRuleGuide.entry(for: rule).title).multilineTextAlignment(.leading)
                            Spacer(minLength: 4)
                            Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                        }
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
                }
            }
        }
    }
}

struct HouseRuleEntryView: View {
    let entry: HouseRuleGuide.Entry
    let onClose: () -> Void

    var body: some View {
        LearningPage(title: "House rule", onClose: onClose) {
            Text(entry.title).font(.system(.title, design: .serif).weight(.bold))
                .accessibilityAddTraits(.isHeader)
            ForEach(Array(entry.paragraphs.enumerated()), id: \.offset) { _, paragraph in
                Text(paragraph).fixedSize(horizontal: false, vertical: true)
            }
            Divider().overlay(Theme.Paper.rule)
            Text("Worked example").font(.headline).accessibilityAddTraits(.isHeader)
            Text(entry.example).fixedSize(horizontal: false, vertical: true)
        }
    }
}

struct HouseRuleSearchResults: View {
    let query: String
    let onSelect: (HouseRuleGuide.Entry) -> Void

    var body: some View {
        let entries = HouseRuleGuide.search(query)
        VStack(alignment: .leading, spacing: 0) {
            if entries.isEmpty {
                Text("No house rules found")
                    .font(.system(.title3, design: .serif).weight(.semibold))
                Text("Try a shorter phrase, such as highest trump, dealer match, or 9 and out.")
                    .padding(.top, 8)
            } else {
                ForEach(entries) { entry in
                    Button { onSelect(entry) } label: {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(alignment: .firstTextBaseline) {
                                Text(entry.title).font(.system(.headline, design: .serif))
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                            }
                            Text(entry.example).font(.subheadline).foregroundStyle(Theme.Paper.ink.opacity(0.8))
                                .lineLimit(3)
                        }
                        .multilineTextAlignment(.leading)
                        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        .padding(.vertical, 12).contentShape(Rectangle())
                    }
                    .buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
                    Divider().overlay(Theme.Paper.rule.opacity(0.5))
                }
            }
        }
        .foregroundStyle(Theme.Paper.ink)
    }
}
