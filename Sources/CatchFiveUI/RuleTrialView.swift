import CatchFive
import SwiftUI

/// "Try it" under a rule: the small position, the choices, and the engine's verdict on each attempt.
/// Refusals stay inline in the same words the table uses; an acceptance shows what followed.
struct RuleTrialView: View {
    @State private var trial: RuleTrial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(kind: RuleTrial.Kind) {
        _trial = State(initialValue: RuleTrial.make(kind))
    }

    private var motion: Animation { reduceMotion ? Theme.Motion.reduced : Theme.Motion.overlay }
    private var names: [String] { Settings.defaultSeatNames }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("TRY IT").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).foregroundStyle(.gold)
                Spacer()
                Button("Reset") { withAnimation(motion) { trial.reset() } }
                    .font(.footnote.weight(.semibold)).tint(.ivory.opacity(0.85))
                    .disabled(trial.outcome == nil)
            }
            Text(trial.prompt).font(.footnote).opacity(0.9).fixedSize(horizontal: false, vertical: true)
            if trial.kind == .followSuit { tableAndHand } else { auctionChoices }
            verdict
        }
        .padding(14)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(.gold.opacity(0.35)))
        .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        .accessibilityElement(children: .contain)
    }

    /// The cards on the table so far, then your hand as tappable cards.
    private var tableAndHand: some View {
        VStack(spacing: 10) {
            HStack(spacing: 8) {
                ForEach(trial.match.hand.currentTrick.isEmpty ? trial.match.hand.completedTricks.last?.plays ?? [] : trial.match.hand.currentTrick,
                        id: \.seat) { play in
                    VStack(spacing: 3) {
                        CardView(card: play.card, width: 40, style: .rest,
                                 ring: trial.match.hand.completedTricks.last?.winner == play.seat && trial.match.hand.currentTrick.isEmpty ? .gold : nil)
                        Text(play.seat == 0 ? "You" : names[play.seat]).font(.caption2).opacity(0.7)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            HStack(spacing: 6) {
                ForEach(trial.offeredCards, id: \.self) { card in
                    Button { withAnimation(motion) { _ = trial.attempt(.play(card)) } } label: {
                        CardView(card: card, width: 44, style: trial.match.hand.nextSeat == 0 ? .playable : .rest)
                    }
                    .buttonStyle(.plain)
                    .disabled(trial.match.hand.nextSeat != 0)
                    .accessibilityLabel(card.name)
                    .accessibilityHint(Text("Try playing this card"))
                }
            }
        }
    }

    /// The auction choices as small pills; the engine grants or refuses each.
    private var auctionChoices: some View {
        HStack(spacing: 6) {
            ForEach(Array(trial.offeredActions.enumerated()), id: \.offset) { _, action in
                Button { withAnimation(motion) { _ = trial.attempt(action) } } label: {
                    Text(label(for: action)).font(.footnote.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
                        .frame(maxWidth: .infinity).frame(minHeight: 40)
                        .background(Theme.Wood.inlay.opacity(0.85), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 10, style: .continuous).stroke(.ivory.opacity(0.18)))
                }
                .buttonStyle(.plain)
                .disabled(trial.outcome != nil && isAccepted(trial.outcome))
            }
        }
    }

    @ViewBuilder private var verdict: some View {
        switch trial.outcome {
        case let .refused(reason)?:
            Label(reason, systemImage: "hand.raised").font(.footnote).foregroundStyle(.ivory.opacity(0.95))
                .transition(.opacity)
        case let .accepted(text)?:
            Label(text, systemImage: "checkmark.circle").font(.footnote).foregroundStyle(.gold)
                .transition(.opacity)
        case nil:
            Text("The engine will judge whatever you try.").font(.caption2).opacity(0.55)
        }
    }

    private func label(for action: PlayerAction) -> String {
        switch action {
        case .bid(nil): "Pass"
        case let .bid(amount?): "Bid \(amount)"
        case .nineAndOut: "9 and out"
        default: "Try"
        }
    }

    private func isAccepted(_ outcome: RuleTrial.Outcome?) -> Bool {
        if case .accepted = outcome { return true }
        return false
    }
}
