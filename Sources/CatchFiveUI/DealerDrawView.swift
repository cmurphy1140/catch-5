import CatchFive
import SwiftUI

/// The draw for dealer, laid over the table before the first hand: each seat's card face up beside
/// its portrait, the winner's card ringed, one sentence, and a Deal button. It also goes away by
/// itself after a moment, and any first action puts it away.
struct DealerDrawView: View {
    let draw: DealerDraw
    let names: [String]
    let portraits: [Portrait]
    let onDismiss: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    var body: some View {
        ZStack {
            Color.black.opacity(contrast == .increased ? 0.75 : 0.55).ignoresSafeArea()
            VStack(spacing: 18) {
                Text("DRAW FOR DEALER").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.7)
                seat(2)
                HStack(spacing: 24) { seat(1); seat(3) }
                seat(0)
                Text(draw.sentence(names: names)).font(.system(.title3, design: .serif).weight(.semibold))
                    .multilineTextAlignment(.center).fixedSize(horizontal: false, vertical: true)
                Button(action: onDismiss) {
                    Text("Deal").font(.headline).frame(maxWidth: .infinity).frame(minHeight: 48)
                }
                .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
            }
            .padding(22)
            .frame(maxWidth: 360)
            .background(Theme.Wood.inlay.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.ivory.opacity(0.18), lineWidth: 1))
            .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
            .foregroundStyle(.ivory)
            .padding(24)
            .dynamicTypeSize(...Theme.Card.maximumTypeSize)
        }
        .accessibilityAddTraits(.isModal)
        .task {
            try? await Task.sleep(for: Theme.Motion.dealerDrawHold)
            guard !Task.isCancelled else { return }
            onDismiss()
        }
    }

    /// A seat's portrait and its drawn card; the dealer's card wears the gold ring.
    private func seat(_ index: Int) -> some View {
        HStack(spacing: 10) {
            PortraitView(portrait: portraits[index], size: 30)
            CardView(card: draw.cards[index], width: 40, style: .rest, ring: index == draw.dealer ? .gold : nil)
            Text(index == 0 ? "You" : names[index]).font(.subheadline.weight(.semibold)).lineLimit(1).fixedSize()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(index == 0 ? "You" : names[index]): the \(draw.cards[index].name)\(index == draw.dealer ? ", deals" : "")")
    }
}
