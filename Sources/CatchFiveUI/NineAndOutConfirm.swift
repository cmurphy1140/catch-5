import SwiftUI

/// The 9-and-out check, asked by the partner across the table (D70): their portrait and name, one line in
/// their voice, a gold "I'm sure" that sends the bid, and "Not this time", which is always there. A card of
/// its own rather than a system dialog, which on iOS 26 anchors to its button and drops Cancel (D57).
struct NineAndOutConfirm: View {
    static let line = "Are you sure? Take all nine and we win the match. Miss one and we lose it."

    /// The name of the phone holder's partner, who does the asking.
    @MainActor static func partnerName(_ model: GameModel) -> String { model.seatNames[model.partnerSeat] }

    let name: String
    let portrait: Portrait
    var figure: Image?
    let onSure: () -> Void
    let onCancel: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
                .onTapGesture(perform: onCancel)
            VStack(spacing: 16) {
                SeatFace(portrait: portrait, figure: figure, size: 80)
                Text(name)
                    .font(.system(.title2, design: .serif).weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
                Text(Self.line)
                    .font(.system(.body, design: .serif)).multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                VStack(spacing: 10) {
                    Button(action: onSure) { Text("I'm sure").font(.headline).frame(maxWidth: .infinity).frame(minHeight: 48) }
                        .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(Theme.Wood.header)
                        .accessibilityHint("Bids 9 and out")
                    MenuButtons.plain("Not this time", action: onCancel)
                }
                .padding(.top, 4)
            }
            .padding(24)
            .frame(maxWidth: 360)
            .foregroundStyle(.ivory)
            .background(Theme.Wood.inlay, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 20, style: .continuous).stroke(.ivory.opacity(0.14)))
            .padding(24)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }
}
