import CatchFive
import SwiftUI

/// The playing field (D97): a walnut panel inlaid in the oak where the trick is played. Its grain runs across the
/// oak's, a maple stringing line runs just inside its edge, it sits a little below the oak (shadowed under its top
/// edge, its lower lip catching the light), and once trump is named the suit is inlaid at its centre. A pool of
/// lamplight lies in front of the seat whose turn it is. Nothing on it is a control.
struct TableField: View {
    /// The panel's frame in the space of the view this is the background of.
    let rect: CGRect
    let trump: Suit?
    /// The place (0 you, 1 left, 2 across, 3 right) of the seat to act, or nil when nobody is.
    let lamp: Int?
    /// The trial layouts lay a blue cloth in the panel instead of walnut (D114).
    var cloth = false
    var colours = Settings.TableColours.charcoal
    /// The room table (D158) lays its own felt across the whole screen, so the field draws only the lamp and trump.
    var bare = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        ZStack(alignment: .topLeading) {
            // The walnut is drawn once for the whole surface and only its window moves, so the grain never redraws
            // while the field changes shape between the auction and play.
            if bare {
                EmptyView()
            } else if cloth {
                shape.fill(RadialGradient(colors: Theme.Field.cloth(colours),
                                          center: .init(x: 0.5, y: 0.48), startRadius: 10, endRadius: max(rect.width, rect.height) * 0.62))
                    .frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY)
                // The nap (D149), drawn once for the whole surface like the walnut, so it stays put while the cloth
                // changes shape.
                ClothNap().equatable()
                    .mask(alignment: .topLeading) { shape.frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY) }
            } else {
            WalnutGrain().equatable()
                .mask(alignment: .topLeading) { shape.frame(width: rect.width, height: rect.height).offset(x: rect.minX, y: rect.minY) }
            }
            ZStack {
                lampPool
                if let trump {
                    if cloth {
                        // On the cloth the suit is woven in, large and faint, low enough to clear the partner (D143).
                        Text(trump.glyph).font(.system(size: min(rect.width * 0.5, 190)))
                            .foregroundStyle(trump.isRed ? Color.suitRed : Color.ivory).opacity(trump.isRed ? 0.3 : 0.2)
                            .offset(y: rect.height * 0.16).transition(.opacity)
                    } else {
                        TrumpInlay(suit: trump, size: min(rect.width * 0.55, Theme.Field.inlayMaximum)).transition(.opacity)
                    }
                }
                if !bare {
                // Recessed: the oak's edge throws a shadow across the top of the panel.
                shape.stroke(.black.opacity(0.55), lineWidth: 10).blur(radius: 7).offset(y: 4).clipShape(shape)
                // The lower lip catches the light.
                shape.inset(by: 0.75).stroke(LinearGradient(stops: [.init(color: .clear, location: 0.55),
                                                                     .init(color: Theme.Wood.streakLight.opacity(0.55), location: 1)],
                                                             startPoint: .top, endPoint: .bottom), lineWidth: 1.5)
                if cloth {
                    // The rail (D117): a band round the cloth, lit from above, a gold line where it meets the cloth. It is
                    // mahogany (D156), the only mahogany on the table; everything else stays oak.
                    MahoganyRail(radius: radius, width: Theme.Field.railWidth)
                    shape.strokeBorder(LinearGradient(colors: [.white.opacity(0.16), .clear, .black.opacity(0.3)], startPoint: .top, endPoint: .bottom),
                                       lineWidth: Theme.Field.railWidth)
                    shape.inset(by: Theme.Field.railWidth).stroke(Theme.Paper.rule.opacity(0.9), lineWidth: 1.5)
                    shape.stroke(Theme.Wood.streakDark.opacity(0.8), lineWidth: 1)
                } else {
                stringing
                shape.stroke(Theme.Wood.header.opacity(0.7), lineWidth: 1)
                }
                }
            }
            .frame(width: rect.width, height: rect.height)
            .offset(x: rect.minX, y: rect.minY)
        }
        // Under Reduce Motion the field and the lamp change in place; nothing slides.
        .animation(reduceMotion ? nil : .spring(duration: 0.5, bounce: 0), value: rect)
        .animation(reduceMotion ? nil : .spring(duration: 0.6, bounce: 0), value: lamp)
        .animation(Theme.Motion.overlay, value: trump)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    /// The panel's corners: the walnut's own, or, for the cloth, round enough that the table reads as an oval (D117).
    private var radius: Double { cloth ? min(rect.width, rect.height) * Theme.Field.clothRounding : Theme.Field.cornerRadius }

    /// A strip of maple set into the walnut just inside its edge, with a dark seam on either side.
    private var stringing: some View {
        let inset = Theme.Field.stringingInset
        let inner = RoundedRectangle(cornerRadius: Theme.Field.cornerRadius - inset, style: .continuous)
        return ZStack {
            inner.inset(by: inset).stroke(Theme.Field.walnutDark, lineWidth: Theme.Field.stringingWidth + 1.4)
            inner.inset(by: inset).stroke(Theme.Field.maple.opacity(0.85), lineWidth: Theme.Field.stringingWidth)
        }
    }

    /// A soft warm pool between the middle of the field and the seat to act.
    @ViewBuilder private var lampPool: some View {
        let radius = min(rect.width, rect.height) * 0.62
        Circle()
            .fill(RadialGradient(colors: [Theme.Field.lamp.opacity(Theme.Field.lampOpacity), Theme.Field.lamp.opacity(0)],
                                 center: .center, startRadius: 0, endRadius: radius))
            .frame(width: radius * 2, height: radius * 2)
            .offset(Self.lampOffset(place: lamp, size: rect.size))
            .opacity(lamp == nil ? 0 : 1)
            .frame(width: rect.width, height: rect.height)
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    /// Where the lamp sits for a place, from the field's centre: most of the way toward that seat's edge.
    nonisolated static func lampOffset(place: Int?, size: CGSize) -> CGSize {
        switch place {
        case 1: CGSize(width: -size.width * 0.5, height: 0)
        case 2: CGSize(width: 0, height: -size.height * 0.5)
        case 3: CGSize(width: size.width * 0.5, height: 0)
        case 0: CGSize(width: 0, height: size.height * 0.5)
        default: .zero
        }
    }
}

/// Trump inlaid in the walnut (D97): the suit cut in maple for spades and clubs, in a red wood for hearts and diamonds,
/// with a dark seam round it, the grain of the field running on through it.
struct TrumpInlay: View {
    let suit: Suit
    let size: Double

    /// The wood a suit is inlaid in.
    nonisolated static func wood(for suit: Suit) -> Color { suit.isRed ? Theme.Field.inlayRed : Theme.Field.maple }

    var body: some View {
        ZStack {
            Text(suit.glyph).font(.system(size: size)).foregroundStyle(Theme.Field.walnutDark)
                .offset(y: -1).blur(radius: 0.6)
            Text(suit.glyph).font(.system(size: size)).foregroundStyle(Self.wood(for: suit))
                .overlay {
                    // A few fine lines of figure so the inlay reads as wood, not paint.
                    LinearGradient(stops: [.init(color: .black.opacity(0.0), location: 0), .init(color: .black.opacity(0.18), location: 0.5),
                                           .init(color: .black.opacity(0.0), location: 1)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                        .mask(Text(suit.glyph).font(.system(size: size)))
                }
        }
        .opacity(Theme.Field.inlayOpacity)
        .accessibilityHidden(true)
    }
}

/// The walnut itself: a dark warm base lit toward the middle, with fine grain running top to bottom, across the oak's.
struct WalnutGrain: View, Equatable {
    nonisolated static func == (lhs: WalnutGrain, rhs: WalnutGrain) -> Bool { true }

    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let bounds = Path(CGRect(origin: .zero, size: size))
            context.fill(bounds, with: .radialGradient(
                Gradient(colors: [Theme.Field.walnutLight, Theme.Field.walnut, Theme.Field.walnutDark]),
                center: CGPoint(x: size.width / 2, y: size.height * 0.48), startRadius: 10, endRadius: max(size.width, size.height) * 0.62))
            var random = GrainRandom(seed: Theme.Wood.seed + 7)
            // Long figure, the way walnut's grain wanders, with a few darker streaks.
            var x = -4.0
            while x < size.width + 4 {
                x += random.next(in: 1.6...4.8)
                let amplitude = random.next(in: 0...1) < 0.15 ? random.next(in: 6...16) : random.next(in: 0.5...4)
                let frequency = random.next(in: 0.004...0.012)
                let phase = random.next(in: 0...(2 * .pi))
                var path = Path()
                path.move(to: CGPoint(x: x, y: -4))
                var y = 0.0
                while y < size.height + 8 {
                    y += 8
                    path.addLine(to: CGPoint(x: x + amplitude * sin(y * frequency + phase), y: y))
                }
                let light = random.next(in: 0...1) < 0.4
                let alpha = random.next(in: 0.04...0.13)
                context.stroke(path, with: .color((light ? Theme.Wood.streakLight : Color.black).opacity(alpha)),
                               lineWidth: random.next(in: 0.5...1.6))
            }
        }
        .accessibilityHidden(true)
    }
}

/// The felt's nap (D149): soft mottling where the cloth has worn, then thousands of short fibres lying every way,
/// some catching the light and some in shadow. It is colourless, so it sits on any of the cloth colours, and it is
/// drawn the same every time.
struct ClothNap: View, Equatable {
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            var random = GrainRandom(seed: 0xF317)
            // Worn patches, blurred into the cloth.
            context.drawLayer { layer in
                layer.addFilter(.blur(radius: 26))
                for _ in 0..<Int(size.width * size.height / 9000) {
                    let w = random.next(in: 50...150), h = random.next(in: 40...110)
                    let spot = CGRect(x: random.next(in: -40...size.width), y: random.next(in: -40...size.height), width: w, height: h)
                    layer.fill(Path(ellipseIn: spot), with: .color(random.next() < 0.5 ? .white.opacity(0.07) : .black.opacity(0.10)))
                }
            }
            // The fibres.
            for _ in 0..<Int(size.width * size.height / 7) {
                let x = random.next(in: 0...size.width), y = random.next(in: 0...size.height)
                let angle = random.next(in: 0...(2 * .pi)), length = random.next(in: 0.8...3.4)
                var fibre = Path()
                fibre.move(to: CGPoint(x: x, y: y))
                fibre.addLine(to: CGPoint(x: x + cos(angle) * length, y: y + sin(angle) * length))
                let light = random.next() < 0.5
                context.stroke(fibre, with: .color(light ? .white.opacity(random.next(in: 0.03...0.13)) : .black.opacity(random.next(in: 0.05...0.20))),
                               lineWidth: 0.7)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The table's trim in mahogany (D156): a deep red-brown band with grain running along it the way a bent rail's does,
/// dark pores broken along their length, and a few pale ribbons of figure crossing it where the wood catches the
/// light. Drawn the same every time.
struct MahoganyRail: View {
    let radius: Double
    let width: Double

    private static let base = Color(red: 0.34, green: 0.11, blue: 0.07)
    private static let deep = Color(red: 0.16, green: 0.04, blue: 0.03)
    private static let glow = Color(red: 0.62, green: 0.26, blue: 0.14)

    var body: some View {
        Canvas { context, size in
            let bounds = CGRect(origin: .zero, size: size)
            func ring(_ inset: Double) -> Path {
                Path(roundedRect: bounds.insetBy(dx: inset, dy: inset), cornerRadius: max(0, radius - inset), style: .continuous)
            }
            // The band itself.
            context.stroke(ring(width / 2), with: .color(Self.base), lineWidth: width)
            var random = GrainRandom(seed: 0x3A40)
            context.drawLayer { layer in
                // Keep everything that follows inside the band.
                var band = ring(0)
                band.addPath(ring(width))
                layer.clip(to: band, style: FillStyle(eoFill: true))
                // Ribbon figure: soft pale and dark bars lying across the rail at a slant.
                layer.drawLayer { figure in
                    figure.addFilter(.blur(radius: 5))
                    for _ in 0..<Int((size.width + size.height) / 9) {
                        let x = random.next(in: -20...size.width), y = random.next(in: -20...size.height)
                        var bar = Path()
                        bar.move(to: CGPoint(x: x, y: y))
                        bar.addLine(to: CGPoint(x: x + random.next(in: 14...34), y: y + random.next(in: 10...26)))
                        figure.stroke(bar, with: .color(random.next() < 0.55 ? Self.glow.opacity(0.5) : Self.deep.opacity(0.55)),
                                      lineWidth: random.next(in: 4...10))
                    }
                }
                // Grain: fine lines running along the rail, some pale, most dark, each broken into runs.
                var inset = 0.4
                while inset < width {
                    let dark = random.next() < 0.62
                    let run = random.next(in: 18...90), gap = random.next(in: 2...14)
                    layer.stroke(ring(inset), with: .color((dark ? Self.deep : Self.glow).opacity(random.next(in: 0.25...0.6))),
                                 style: StrokeStyle(lineWidth: random.next(in: 0.4...1.1), lineCap: .round, dash: [run, gap],
                                                    dashPhase: random.next(in: 0...100)))
                    inset += random.next(in: 0.7...1.5)
                }
                // Pores: short dark flecks along the grain.
                for _ in 0..<Int(width * 2.2) {
                    layer.stroke(ring(random.next(in: 0.5...(width - 0.5))), with: .color(Self.deep.opacity(0.7)),
                                 style: StrokeStyle(lineWidth: 0.7, lineCap: .round, dash: [random.next(in: 1.5...5), random.next(in: 30...140)],
                                                    dashPhase: random.next(in: 0...140)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The far edge of the room table (D158): level across the middle, where the three players sit behind it, and falling
/// away at either side of the screen the way a round table's edge does.
struct TableEdge: Shape {
    /// The edge's height in the shape's own space.
    let top: Double
    /// How far the edge falls at the screen's sides, and how wide each falling shoulder is.
    var fall = 46.0
    var shoulder = 34.0
    /// Closed down to the bottom, for the felt; open, for the rail along the edge.
    var closed = true

    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX - 40, y: top + fall))
        path.addQuadCurve(to: CGPoint(x: rect.minX + shoulder, y: top), control: CGPoint(x: rect.minX, y: top))
        path.addLine(to: CGPoint(x: rect.maxX - shoulder, y: top))
        path.addQuadCurve(to: CGPoint(x: rect.maxX + 40, y: top + fall), control: CGPoint(x: rect.maxX, y: top))
        if closed {
            path.addLine(to: CGPoint(x: rect.maxX + 40, y: rect.maxY + 200))
            path.addLine(to: CGPoint(x: rect.minX - 40, y: rect.maxY + 200))
            path.closeSubpath()
        }
        return path
    }
}

/// The room table's felt (D158): cloth from the far edge down past the bottom of the screen, with its nap, lit toward
/// the middle. The hand, the bids and the trick all lie on it.
struct RoomFelt: View {
    let top: Double
    let colours: Settings.TableColours

    var body: some View {
        GeometryReader { geometry in
            let edge = TableEdge(top: top)
            ZStack {
                edge.fill(RadialGradient(colors: Theme.Field.cloth(colours), center: .init(x: 0.5, y: 0.55), startRadius: 20,
                                         endRadius: max(geometry.size.width, geometry.size.height) * 0.75))
                ClothNap().equatable().mask { edge }
                // The rail's shadow on the cloth just under it.
                TableEdge(top: top + 9, closed: false).stroke(.black.opacity(0.45), lineWidth: 12).blur(radius: 7).mask { edge }
            }
        }
        .accessibilityHidden(true)
    }
}

/// The mahogany rail along the room table's far edge (D156, D158), drawn over the seated players so they sit behind it.
struct RoomRail: View {
    let top: Double

    var body: some View {
        let width = Theme.Field.railWidth
        ZStack {
            TableEdge(top: top, closed: false).stroke(Color(red: 0.34, green: 0.11, blue: 0.07), style: StrokeStyle(lineWidth: width, lineCap: .round))
            // Grain along the rail: broken dark and pale lines.
            ForEach(0..<7, id: \.self) { line in
                let offset = -width / 2 + 1.5 + Double(line) * (width - 3) / 6
                TableEdge(top: top + offset, closed: false)
                    .stroke(line % 3 == 1 ? Color(red: 0.62, green: 0.26, blue: 0.14).opacity(0.5) : Color(red: 0.16, green: 0.04, blue: 0.03).opacity(0.55),
                            style: StrokeStyle(lineWidth: 0.9, lineCap: .round, dash: [Double(30 + line * 17), Double(5 + line * 3)], dashPhase: Double(line * 23)))
            }
            // Lit from above, shaded below, a gold line where it meets the cloth.
            TableEdge(top: top - width / 2 + 1.5, closed: false).stroke(.white.opacity(0.22), lineWidth: 1.5)
            TableEdge(top: top + width / 2, closed: false).stroke(Theme.Paper.rule.opacity(0.9), lineWidth: 1.5)
        }
        .shadow(color: .black.opacity(0.4), radius: 3, y: 2)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
