import CoreImage.CIFilterBuiltins
import SwiftUI

/// A link to hand round the table (D139): a slip of paper with a code the others can scan from her phone, and one
/// way to open it on this one. Links that belong with it sit under the code as plain lines (D140).
struct GuestCodeCard: View {
    let title: String
    let url: URL
    var also: [MainMenuView.GuestPrompt.Also] = []
    let open: (URL) -> Void
    let onDone: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea().onTapGesture(perform: onDone)
            VStack(spacing: 14) {
                if let code = Self.code(for: url.absoluteString) {
                    Image(decorative: code, scale: 1).interpolation(.none).resizable().scaledToFit().frame(width: 200, height: 200)
                        .accessibilityLabel("A code to scan for \(title)")
                }
                Text(title).font(.custom("Noteworthy-Bold", size: 20, relativeTo: .title3)).foregroundStyle(Theme.Paper.ink)
                ForEach(also, id: \.url) { link in
                    Button { open(link.url) } label: { Label(link.label, systemImage: "arrow.up.right") }
                        .font(.custom("Noteworthy-Bold", size: 18, relativeTo: .body)).foregroundStyle(Theme.Paper.green).frame(minHeight: 44)
                }
                HStack(spacing: 28) {
                    Button("Open") { open(url) }
                    Button("Done", action: onDone)
                }
                .font(.headline).foregroundStyle(Theme.Paper.green).frame(minHeight: 44)
            }
            .padding(24)
            .background(Color.ivory, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            .shadow(color: .black.opacity(0.4), radius: 10, y: 6)
        }
        .accessibilityAddTraits(.isModal)
    }

    /// The link as a QR code in the paper's own ink and no background, so it sits on the ivory.
    nonisolated static func code(for text: String) -> CGImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(text.utf8)
        filter.correctionLevel = "M"
        guard let output = filter.outputImage?.transformed(by: CGAffineTransform(scaleX: 8, y: 8)) else { return nil }
        return CIContext().createCGImage(output, from: output.extent)
    }
}
