import CatchFive
import SwiftUI

/// Only the viewer-safe suggestion crosses into this reading view.
struct LiveAdviceView: View {
    let presentation: LiveAdvicePresentation
    let onRule: (ReplayRule) -> Void
    let onClose: () -> Void

    var body: some View {
        LearningPage(title: "Why this move?", onClose: onClose) {
            Text("Suggested move").font(.headline)
            Text(presentation.actionTitle)
                .font(.system(.title, design: .serif).weight(.bold))
                .accessibilityAddTraits(.isHeader)
            if case let .play(card) = presentation.advice.action {
                CardView(card: card, width: 64)
            }
            Text(presentation.advice.reason).fixedSize(horizontal: false, vertical: true)
            Divider().overlay(Theme.Paper.rule)
            LearningRuleLinks(rules: presentation.rules, onRule: onRule)
            Text("A standard-strategy suggestion, using your cards and public play. Other legal choices may be good too.")
                .font(.footnote).foregroundStyle(Theme.Paper.ink.opacity(0.75))
        }
    }
}
