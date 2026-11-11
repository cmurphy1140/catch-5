import SwiftUI

/// "Your turn" as a thing on the table (D150): a scrap torn from the score pad, the words pencilled on it, and the
/// pencil lying across its corner when the build carries that picture. It replaces the ivory pill.
struct TurnSlip: View {
    let prompt: String
    let hint: String
    var pencil: Image? = SeatArt.named("GuestPencil")

    var body: some View {
        VStack(spacing: -2) {
            Text(prompt).font(.custom("Noteworthy-Bold", size: 25, relativeTo: .title2))
            Text(hint).font(.custom("Noteworthy-Light", size: 14, relativeTo: .footnote)).opacity(0.8)
        }
        .lineLimit(1).minimumScaleFactor(0.7)
        .foregroundStyle(Theme.Paper.ink)
        .padding(.horizontal, 30).padding(.top, 7).padding(.bottom, 4)
        .background {
            ZStack {
                TornScrap().fill(Color(red: 0.97, green: 0.94, blue: 0.85)).shadow(color: .black.opacity(0.4), radius: 3, y: 2)
                // The pad's ruled lines and its red margin, faint under the pencil.
                Canvas { context, size in
                    var y = 16.0
                    while y < size.height - 3 {
                        context.fill(Path(CGRect(x: 6, y: y, width: size.width - 12, height: 0.7)), with: .color(Color(red: 0.45, green: 0.58, blue: 0.75).opacity(0.45)))
                        y += 11
                    }
                    context.fill(Path(CGRect(x: 18, y: 5, width: 0.8, height: size.height - 7)), with: .color(Color.suitRed.opacity(0.4)))
                }
                .clipShape(TornScrap())
            }
        }
        .rotationEffect(.degrees(-2))
        .overlay(alignment: .trailing) {
            if let pencil {
                pencil.resizable().scaledToFit().frame(height: 62).rotationEffect(.degrees(28))
                    .shadow(color: .black.opacity(0.35), radius: 2, y: 2).offset(x: 30, y: 2)
                    .accessibilityHidden(true)
            }
        }
    }
}

/// A rectangle of paper whose top edge was torn off a pad: small uneven teeth, the same every time.
struct TornScrap: Shape {
    func path(in rect: CGRect) -> Path {
        var random = GrainRandom(seed: 0x70A2)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + 3))
        var x = rect.minX
        while x < rect.maxX {
            x = min(rect.maxX, x + random.next(in: 3...7))
            path.addLine(to: CGPoint(x: x, y: rect.minY + random.next(in: 0...4)))
        }
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}
