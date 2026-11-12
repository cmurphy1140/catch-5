import SwiftUI

/// A handwritten note to the guest of honour (D137), in the manner of the place cards she wrote for her own wedding:
/// a scalloped pale-blue card with a flowered border, two swans whose necks make a heart, her name on their wings.
/// The words live in the git-ignored data asset `GuestNote`, so no other build has one.
struct GuestNote: Decodable, Equatable {
    let name: String
    let greeting: String
    let body: String
    let signoff: String

    static let current: GuestNote? = {
        #if canImport(UIKit)
        NSDataAsset(name: "GuestNote").flatMap { try? JSONDecoder().decode(GuestNote.self, from: $0.data) }
        #else
        nil
        #endif
    }()
}

/// The note as a card on the table, with one way on.
struct GuestNoteCard: View {
    let note: GuestNote
    let onDone: () -> Void

    private static let blue = Color(red: 0.70, green: 0.79, blue: 0.90)
    private static let ink = Color(red: 0.13, green: 0.13, blue: 0.16)
    private static let penBlue = Color(red: 0.20, green: 0.42, blue: 0.80)

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea().onTapGesture(perform: onDone)
            VStack(spacing: 18) {
                card
                Button("Keep it", action: onDone).buttonStyle(WoodWritingButtonStyle(size: 26)).frame(width: 150)
            }
            .padding(20)
        }
        .accessibilityAddTraits(.isModal)
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 10) {
            Color.clear.frame(height: 44) // the swans come down into here
            Text(note.greeting)
            Text(note.body).fixedSize(horizontal: false, vertical: true)
            Text(note.signoff).frame(maxWidth: .infinity, alignment: .trailing).padding(.trailing, 18)
        }
        .font(.custom("BradleyHandITCTT-Bold", size: 19, relativeTo: .body))
        .lineSpacing(5)
        .foregroundStyle(Self.ink)
        .padding(.horizontal, 30).padding(.vertical, 26)
        .frame(maxWidth: 330)
        .background {
            ZStack {
                Scalloped(bump: 16).fill(Self.blue).shadow(color: .black.opacity(0.4), radius: 10, y: 6)
                Flowers().padding(10).clipShape(Scalloped(bump: 13).inset(by: 10))
                Scalloped(bump: 11).inset(by: 20).fill(Color(red: 0.99, green: 0.98, blue: 0.95))
            }
        }
        .overlay(alignment: .top) { swans.offset(y: -38) }
        .dynamicTypeSize(...DynamicTypeSize.xLarge)
        .accessibilityElement(children: .combine)
    }

    /// Two swans facing each other on the top edge of the card, beaks touching so their necks make a heart; her name
    /// is on each one.
    private var swans: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { mirrored in
                SwanView()
                    .overlay {
                        Text(note.name).font(.custom("SnellRoundhand-Black", fixedSize: 17)).foregroundStyle(Self.penBlue)
                            .scaleEffect(x: mirrored ? -1 : 1) // the swan is flipped; the name is not
                            .offset(x: -20, y: 26)
                    }
                    .frame(width: 124, height: 96)
                    .scaleEffect(x: mirrored ? -1 : 1)
            }
        }
        .shadow(color: .black.opacity(0.3), radius: 2, y: 2)
        .accessibilityHidden(true)
    }
}

/// The note before it is opened (D138): a small place card left on the table with her name on it, as at a wedding
/// seat. She finds it and picks it up; nothing announces it.
struct GuestPlaceCard: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name).font(.custom("SnellRoundhand-Black", fixedSize: 24)).foregroundStyle(Color(red: 0.20, green: 0.42, blue: 0.80))
                .frame(width: 104, height: 64)
                .background {
                    ZStack {
                        Scalloped(bump: 9).fill(Color(red: 0.70, green: 0.79, blue: 0.90)).shadow(color: .black.opacity(0.45), radius: 4, y: 3)
                        Scalloped(bump: 7).inset(by: 7).fill(Color(red: 0.99, green: 0.98, blue: 0.95))
                    }
                }
                .rotationEffect(.degrees(-7))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("A note for \(name)")
        .accessibilityHint("Opens it")
    }
}

/// A rectangle whose edge is a run of small bumps, like a deckle-cut card.
struct Scalloped: InsettableShape {
    var bump: Double
    var inset = 0.0

    func inset(by amount: CGFloat) -> Scalloped { Scalloped(bump: bump, inset: inset + amount) }

    func path(in rect: CGRect) -> Path {
        let r = rect.insetBy(dx: inset + bump / 2, dy: inset + bump / 2)
        var path = Path(r)
        func run(from a: CGPoint, to b: CGPoint) {
            let length = hypot(b.x - a.x, b.y - a.y), count = max(1, Int((length / bump).rounded()))
            for step in 0...count {
                let t = Double(step) / Double(count)
                path.addEllipse(in: CGRect(x: a.x + (b.x - a.x) * t - bump / 2, y: a.y + (b.y - a.y) * t - bump / 2, width: bump, height: bump))
            }
        }
        run(from: CGPoint(x: r.minX, y: r.minY), to: CGPoint(x: r.maxX, y: r.minY))
        run(from: CGPoint(x: r.maxX, y: r.minY), to: CGPoint(x: r.maxX, y: r.maxY))
        run(from: CGPoint(x: r.maxX, y: r.maxY), to: CGPoint(x: r.minX, y: r.maxY))
        run(from: CGPoint(x: r.minX, y: r.maxY), to: CGPoint(x: r.minX, y: r.minY))
        return path
    }
}

/// A small-flowered print: lilac and blue blooms with green leaves, the same every time it is drawn.
private struct Flowers: View {
    var body: some View {
        Canvas { context, size in
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.96, green: 0.96, blue: 0.93)))
            let colours = [Color(red: 0.66, green: 0.68, blue: 0.86), Color(red: 0.60, green: 0.75, blue: 0.90), Color(red: 0.62, green: 0.76, blue: 0.62)]
            var seed: UInt64 = 0x5EED
            func next() -> Double { seed = seed &* 6364136223846793005 &+ 1442695040888963407; return Double(seed >> 33) / Double(1 << 31) }
            for index in 0..<Int(size.width * size.height / 70) {
                let centre = CGPoint(x: next() * size.width, y: next() * size.height), radius = 1.6 + next() * 2.2
                context.fill(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                             with: .color(colours[index % 3].opacity(0.85)))
            }
        }
    }
}

/// One swan in profile, facing right: white, edged in soft blue so it reads on pale paper, with an orange bill and a
/// dark eye. Its bill ends at the right edge, so two of them, one flipped, touch bills and their necks make a heart.
struct SwanView: View {
    var body: some View {
        ZStack {
            SwanOutline().fill(.white)
            SwanOutline().stroke(Color(red: 0.50, green: 0.60, blue: 0.80), lineWidth: 1.3)
            SwanDetail(part: .wing).stroke(Color(red: 0.50, green: 0.60, blue: 0.80), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            SwanDetail(part: .bill).fill(Color(red: 0.93, green: 0.55, blue: 0.20))
            SwanDetail(part: .eye).fill(Color(red: 0.13, green: 0.13, blue: 0.16))
        }
    }
}

private func swanPoint(_ rect: CGRect, _ x: Double, _ y: Double) -> CGPoint {
    CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
}

/// Body, neck and head in one line: a lifted tail, a round breast, a long neck that rises and bows its head.
private struct SwanOutline: Shape {
    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint { swanPoint(rect, x, y) }
        var path = Path()
        path.move(to: p(0.02, 0.44))                                                   // tail tip
        path.addQuadCurve(to: p(0.60, 0.54), control: p(0.30, 0.42))                   // back
        path.addCurve(to: p(0.78, 0.06), control1: p(0.52, 0.30), control2: p(0.58, 0.08)) // back of the neck
        path.addQuadCurve(to: p(0.93, 0.20), control: p(0.90, 0.05))                   // crown and brow
        path.addLine(to: p(0.90, 0.28))                                                // where the bill joins
        path.addQuadCurve(to: p(0.80, 0.24), control: p(0.85, 0.31))                   // chin
        path.addCurve(to: p(0.77, 0.62), control1: p(0.68, 0.24), control2: p(0.68, 0.46)) // front of the neck
        path.addCurve(to: p(0.44, 0.97), control1: p(0.88, 0.82), control2: p(0.70, 0.97)) // breast
        path.addCurve(to: p(0.02, 0.44), control1: p(0.18, 0.97), control2: p(0.08, 0.70)) // belly up to the tail
        path.closeSubpath()
        return path
    }
}

private struct SwanDetail: Shape {
    enum Part { case wing, bill, eye }
    let part: Part

    func path(in rect: CGRect) -> Path {
        func p(_ x: Double, _ y: Double) -> CGPoint { swanPoint(rect, x, y) }
        var path = Path()
        switch part {
        case .wing: // the folded wing's top edge, with two feather tips at the back
            path.move(to: p(0.60, 0.62))
            path.addQuadCurve(to: p(0.12, 0.50), control: p(0.34, 0.46))
            path.addQuadCurve(to: p(0.17, 0.60), control: p(0.18, 0.54))
            path.move(to: p(0.12, 0.50))
            path.addQuadCurve(to: p(0.10, 0.58), control: p(0.13, 0.54))
        case .bill:
            path.move(to: p(0.93, 0.20)); path.addLine(to: p(1.0, 0.33)); path.addLine(to: p(0.90, 0.28)); path.closeSubpath()
        case .eye:
            let c = p(0.86, 0.17)
            path.addEllipse(in: CGRect(x: c.x - 1.6, y: c.y - 1.6, width: 3.2, height: 3.2))
        }
        return path
    }
}
