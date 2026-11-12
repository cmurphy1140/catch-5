import SwiftUI

/// The guest's letter stays in the git-ignored data asset, separate from editable Notebook entries.
struct GuestNote: Decodable, Equatable {
    let name: String
    let greeting: String
    let body: String
    let signoff: String

    /// Records that the letter was presented, not that its reader finished it.
    static let seenKey = "guestNote.seen"

    static let current: GuestNote? = {
        #if canImport(UIKit)
        NSDataAsset(name: "GuestNote").flatMap { try? JSONDecoder().decode(GuestNote.self, from: $0.data) }
        #else
        nil
        #endif
    }()
}

/// The wedding stationery is a reading surface: the whole letter scrolls, while its return stays within reach.
struct GuestNoteCard: View {
    let note: GuestNote
    let onDone: () -> Void

    @AppStorage(GuestNote.seenKey) private var wasOpened = false

    private static let blue = Color(red: 0.70, green: 0.79, blue: 0.90)
    private static let ink = Color(red: 0.13, green: 0.13, blue: 0.16)
    private static let penBlue = Color(red: 0.20, green: 0.42, blue: 0.80)

    var body: some View {
        ZStack {
            Color.black.opacity(0.78).ignoresSafeArea()
                .onTapGesture(perform: onDone).accessibilityHidden(true)
            VStack(spacing: 12) {
                ScrollView {
                    card.padding(.horizontal, 16).padding(.top, 16).padding(.bottom, 8)
                }
                .scrollBounceBehavior(.basedOnSize)
                Button("Keep it", action: onDone)
                    .font(.system(.headline, design: .serif))
                    .foregroundStyle(Color.ivory)
                    .padding(.horizontal, 28).padding(.vertical, 12)
                    .frame(minWidth: 120, minHeight: 48)
                    .background(Theme.Paper.green, in: Capsule())
                    .buttonStyle(.plain)
                    .keyboardShortcut(.cancelAction)
                    .accessibilityHint("Returns to where you opened the letter")
            }
            .frame(maxWidth: 580)
            .padding(.vertical, 12)
        }
        .accessibilityAddTraits(.isModal)
        .accessibilityAction(.escape, onDone)
        .onAppear { wasOpened = true }
    }

    private var card: some View {
        VStack(alignment: .leading, spacing: 20) {
            swans.frame(maxWidth: .infinity).padding(.bottom, 2)
            Text(note.greeting)
                .font(.system(.title2, design: .serif).weight(.semibold))
                .accessibilityAddTraits(.isHeader)
            Text(note.body)
                .font(.system(.title3, design: .serif))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
            Text(note.signoff)
                .font(.system(.title3, design: .serif).italic())
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, 4)
        }
        .lineSpacing(6)
        .foregroundStyle(Self.ink)
        .padding(.horizontal, 30).padding(.vertical, 24)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack {
                Scalloped(bump: 14).fill(Self.blue).shadow(color: .black.opacity(0.32), radius: 8, y: 5)
                Flowers().padding(8).clipShape(Scalloped(bump: 11).inset(by: 8))
                Scalloped(bump: 9).inset(by: 17).fill(Color(red: 0.99, green: 0.98, blue: 0.95))
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var swans: some View {
        HStack(spacing: 0) {
            ForEach([false, true], id: \.self) { mirrored in
                SwanView()
                    .overlay {
                        Text(note.name).font(.custom("SnellRoundhand-Black", fixedSize: 12)).foregroundStyle(Self.penBlue)
                            .scaleEffect(x: mirrored ? -1 : 1)
                            .offset(x: -13, y: 18)
                    }
                    .frame(width: 84, height: 66)
                    .scaleEffect(x: mirrored ? -1 : 1)
            }
        }
        .accessibilityHidden(true)
    }
}

/// One entrance for the gift, with the opened state shared by the Notebook and the guest's page.
struct GuestMailboxButton: View {
    let name: String
    var showsPortrait = true
    var ink = Theme.Paper.ink
    let action: () -> Void

    @AppStorage(GuestNote.seenKey) private var wasOpened = false
    @Environment(\.dynamicTypeSize) private var typeSize

    var body: some View {
        Button(action: action) {
            Group {
                if typeSize.isAccessibilitySize {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(alignment: .bottom) {
                            GuestMailboxArt(opened: wasOpened).frame(width: 82, height: 112)
                            Spacer(minLength: 16)
                            if showsPortrait { portrait }
                        }
                        title
                    }
                } else {
                    HStack(alignment: .center, spacing: 10) {
                        GuestMailboxArt(opened: wasOpened).frame(width: 82, height: 112)
                        title.layoutPriority(1)
                        if showsPortrait {
                            Spacer(minLength: 0)
                            portrait
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: 112, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("For \(name)")
        .accessibilityValue(wasOpened ? "Opened letter" : "Unopened letter")
        .accessibilityHint("Opens your letter")
    }

    private var title: some View {
        Text("For \(name)").font(.system(.title2, design: .serif).weight(.semibold))
            .foregroundStyle(ink).multilineTextAlignment(.leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder private var portrait: some View {
        if let picture = SeatArt.named("Guest") {
            picture.resizable().scaledToFit()
                .frame(width: typeSize.isAccessibilitySize ? 90 : 100, height: 138, alignment: .bottom)
                .accessibilityHidden(true)
        }
    }
}

/// A little rural mailbox: curved green steel, a short walnut post, and a flag that folds after discovery.
private struct GuestMailboxArt: View {
    let opened: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Canvas { context, size in
                context.scaleBy(x: size.width / 130, y: size.height / 154)
                func polygon(_ points: [CGPoint]) -> Path {
                    var path = Path()
                    guard let first = points.first else { return path }
                    path.move(to: first)
                    for point in points.dropFirst() { path.addLine(to: point) }
                    path.closeSubpath()
                    return path
                }
                let post = polygon([CGPoint(x: 56, y: 79), CGPoint(x: 76, y: 81), CGPoint(x: 76, y: 142), CGPoint(x: 56, y: 138)])
                context.fill(post, with: .linearGradient(Gradient(colors: [
                    Color(red: 0.46, green: 0.29, blue: 0.14), Color(red: 0.64, green: 0.43, blue: 0.22),
                    Color(red: 0.38, green: 0.23, blue: 0.12)
                ]), startPoint: CGPoint(x: 56, y: 0), endPoint: CGPoint(x: 76, y: 0)))
                let postSide = polygon([CGPoint(x: 76, y: 81), CGPoint(x: 84, y: 77), CGPoint(x: 84, y: 138), CGPoint(x: 76, y: 142)])
                context.fill(postSide, with: .color(Color(red: 0.34, green: 0.21, blue: 0.12)))
                for x in [60.0, 66.0, 71.0] {
                    var grain = Path()
                    grain.move(to: CGPoint(x: x, y: 88)); grain.addLine(to: CGPoint(x: x - 1, y: 134))
                    context.stroke(grain, with: .color(.black.opacity(0.12)), lineWidth: 0.7)
                }

                var side = Path()
                side.move(to: CGPoint(x: 18, y: 81))
                side.addLine(to: CGPoint(x: 18, y: 54))
                side.addCurve(to: CGPoint(x: 46, y: 24), control1: CGPoint(x: 18, y: 32), control2: CGPoint(x: 28, y: 20))
                side.addLine(to: CGPoint(x: 98, y: 31))
                side.addCurve(to: CGPoint(x: 110, y: 56), control1: CGPoint(x: 109, y: 34), control2: CGPoint(x: 111, y: 43))
                side.addLine(to: CGPoint(x: 92, y: 91)); side.closeSubpath()
                context.fill(side, with: .linearGradient(Gradient(colors: [
                    Color(red: 0.34, green: 0.45, blue: 0.30), Color(red: 0.16, green: 0.30, blue: 0.20),
                    Color(red: 0.11, green: 0.24, blue: 0.16)
                ]), startPoint: CGPoint(x: 28, y: 24), endPoint: CGPoint(x: 75, y: 91)))
                context.stroke(side, with: .color(Color(red: 0.10, green: 0.20, blue: 0.13)), lineWidth: 1.5)

                var door = Path()
                door.move(to: CGPoint(x: 92, y: 91)); door.addLine(to: CGPoint(x: 92, y: 57))
                door.addCurve(to: CGPoint(x: 119, y: 53), control1: CGPoint(x: 92, y: 31), control2: CGPoint(x: 119, y: 25))
                door.addLine(to: CGPoint(x: 119, y: 83)); door.closeSubpath()
                context.fill(door, with: .linearGradient(Gradient(colors: [
                    Color(red: 0.28, green: 0.39, blue: 0.25), Color(red: 0.15, green: 0.28, blue: 0.18)
                ]), startPoint: CGPoint(x: 99, y: 37), endPoint: CGPoint(x: 117, y: 85)))
                context.stroke(door, with: .color(Color(red: 0.08, green: 0.18, blue: 0.12)), lineWidth: 1.5)

                var seam = Path()
                seam.move(to: CGPoint(x: 21, y: 56)); seam.addLine(to: CGPoint(x: 88, y: 64))
                context.stroke(seam, with: .color(.black.opacity(0.24)), lineWidth: 1)
                var highlight = Path()
                highlight.move(to: CGPoint(x: 24, y: 42))
                highlight.addQuadCurve(to: CGPoint(x: 47, y: 28), control: CGPoint(x: 31, y: 25))
                highlight.addLine(to: CGPoint(x: 91, y: 34))
                context.stroke(highlight, with: .color(Color.ivory.opacity(0.3)), style: StrokeStyle(lineWidth: 1.4, lineCap: .round))
                let latch = Path(roundedRect: CGRect(x: 106, y: 46, width: 12, height: 5), cornerRadius: 1.5)
                context.fill(latch, with: .color(Color(red: 0.74, green: 0.68, blue: 0.48)))
                context.stroke(latch, with: .color(.black.opacity(0.3)), lineWidth: 0.7)
            }
            GuestMailboxFlag()
                .fill(Color(red: 0.71, green: 0.20, blue: 0.13))
                .overlay { GuestMailboxFlag().stroke(Color(red: 0.40, green: 0.10, blue: 0.07), lineWidth: 0.7) }
                .rotationEffect(.degrees(opened ? 90 : 0), anchor: UnitPoint(x: 80.0 / 130, y: 62.0 / 154))
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.35), value: opened)
            Canvas { context, size in
                let pin = CGRect(x: size.width * 76 / 130, y: size.height * 58 / 154, width: size.width * 8 / 130, height: size.height * 8 / 154)
                context.fill(Path(ellipseIn: pin), with: .color(Color(red: 0.77, green: 0.69, blue: 0.47)))
                context.stroke(Path(ellipseIn: pin.insetBy(dx: 1.1, dy: 1.1)), with: .color(.black.opacity(0.4)), lineWidth: 0.7)
            }
        }
        .shadow(color: .black.opacity(0.12), radius: 1.5, y: 2)
        .accessibilityHidden(true)
    }
}

private struct GuestMailboxFlag: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 78, y: 63)); path.addLine(to: CGPoint(x: 78, y: 13))
        path.addLine(to: CGPoint(x: 99, y: 13)); path.addLine(to: CGPoint(x: 99, y: 29))
        path.addLine(to: CGPoint(x: 82, y: 29)); path.addLine(to: CGPoint(x: 82, y: 63))
        path.closeSubpath()
        return path.applying(CGAffineTransform(scaleX: rect.width / 130, y: rect.height / 154))
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
