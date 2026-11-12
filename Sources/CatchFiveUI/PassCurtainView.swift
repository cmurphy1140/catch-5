import SwiftUI

/// Pass and play's curtain: the whole screen, nothing of the table behind it, until the player the phone was
/// passed to taps Ready. Their hand appears only then, so no one sees a hand that is not theirs.
struct PassCurtainView: View {
    let name: String
    let portrait: Portrait
    var figure: Image?
    let onReady: () -> Void

    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            SeatFace(portrait: portrait, figure: figure, size: 96)
            VStack(spacing: 6) {
                Text("PASS THE PHONE TO")
                    .font(.system(.caption, design: .monospaced).weight(.semibold)).tracking(2).opacity(0.82)
                Text(name)
                    .font(.system(size: 40, weight: .bold, design: .serif)).lineLimit(1).minimumScaleFactor(0.5)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Pass the phone to \(name)")
            Text("Tap Ready when only \(name) can see the screen.")
                .font(.footnote).multilineTextAlignment(.center).opacity(0.75)
            Spacer()
            MenuButtons.prominent("Ready", action: onReady)
                .accessibilityHint("Shows \(name)'s hand")
        }
        .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity, maxHeight: .infinity)
        .foregroundStyle(.ivory)
        .background(WoodGrainView().ignoresSafeArea())
        .accessibilityAddTraits(.isModal)
    }
}
