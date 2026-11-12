import SwiftUI
#if canImport(CoreMotion) && os(iOS)
import CoreMotion
#endif

/// The opening table's motion (D179), taken from Connor's Figma prototype: the numbers that can be checked without a
/// screen live here, and the moving pieces below.
enum HomeMotion {
    /// The line over the title, by the hour: "Evening at the Emma table".
    nonisolated static func greeting(hour: Int, guest: String?) -> String {
        let part = switch hour {
        case 5..<12: "Morning"
        case 12..<17: "Afternoon"
        case 17..<22: "Evening"
        default: "Late night"
        }
        return guest.map { "\(part) at the \($0) table" } ?? "\(part) at the table"
    }

    /// Where a dealt card lands by each of the five on the blanket, as a point in the family picture, and its turn.
    static let seats: [(x: Double, y: Double, turn: Double)] = [
        (0.18, 0.70, -18), (0.38, 0.66, 8), (0.59, 0.75, -6), (0.76, 0.70, 14), (0.88, 0.79, -10),
    ]
    /// The deck's place in the family picture, where `PicnicDeck` lies.
    static let deck = (x: 0.43, y: 0.845)
    static let dealStagger = 0.105, dealSeconds = 1.15

    /// How far the five leans for the phone's roll and pitch (in degrees, pitch measured from the usual 45° hold):
    /// up to `lean` degrees each way, and where the glare sits on the card, 0 to 1.
    nonisolated static func lean(roll: Double, pitch: Double, lean: Double = 5) -> (x: Double, y: Double, glareX: Double, glareY: Double) {
        let side = max(-25, min(25, roll)) / 25, tip = max(-25, min(25, pitch - 45)) / 25
        return (-tip * lean, side * lean, 0.5 + side * 0.4, 0.5 + tip * 0.4)
    }
}

/// The phone's lean, read a few times a second while the opening table is up. Without motion sensors it stays level.
@MainActor final class PhoneTilt: ObservableObject {
    @Published private(set) var roll = 0.0
    @Published private(set) var pitch = 45.0
    #if canImport(CoreMotion) && os(iOS)
    private let manager = CMMotionManager()
    #endif

    func start() {
        #if canImport(CoreMotion) && os(iOS)
        guard manager.isDeviceMotionAvailable, !manager.isDeviceMotionActive else { return }
        manager.deviceMotionUpdateInterval = 1.0 / 20
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let attitude = motion?.attitude else { return }
            let roll = attitude.roll * 180 / .pi, pitch = attitude.pitch * 180 / .pi
            MainActor.assumeIsolated {
                guard let self, abs(roll - self.roll) > 0.4 || abs(pitch - self.pitch) > 0.4 else { return }
                self.roll = roll; self.pitch = pitch
            }
        }
        #endif
    }

    func stop() {
        #if canImport(CoreMotion) && os(iOS)
        manager.stopDeviceMotionUpdates()
        #endif
    }
}

/// The five's outline inside the hero picture (1066 by 730), so light can fall on the card and not on the hands.
struct HeroCardOutline: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let corners = [(308.0, 243.0), (540.0, 150.0), (756.0, 556.0), (498.0, 690.0)]
        for (index, corner) in corners.enumerated() {
            let point = CGPoint(x: rect.minX + corner.0 / 1066 * rect.width, y: rect.minY + corner.1 / 730 * rect.height)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// The five held over the table, alive (D179): it floats a little, leans as the phone leans with a glare that moves
/// across it, and every few seconds light glints over its face.
struct HomeHero: View {
    let picture: Image
    let width: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var tilt = PhoneTilt()
    @State private var afloat = false
    @State private var glint = false

    var body: some View {
        let lean = HomeMotion.lean(roll: tilt.roll, pitch: tilt.pitch)
        picture.resizable().scaledToFit().frame(width: width)
            .overlay {
                GeometryReader { geometry in
                    let size = geometry.size
                    ZStack {
                        // The glare that follows the phone.
                        RadialGradient(colors: [Color(red: 1, green: 0.98, blue: 0.92).opacity(0.6), .clear],
                                       center: UnitPoint(x: 0.29 + lean.glareX * 0.42, y: 0.2 + lean.glareY * 0.75),
                                       startRadius: 0, endRadius: size.width * 0.3)
                            .opacity(0.5)
                        // The glint that crosses now and then.
                        LinearGradient(colors: [.clear, Color(red: 1, green: 0.99, blue: 0.94).opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: size.width * 0.16, height: size.height * 1.4).rotationEffect(.degrees(25))
                            .offset(x: glint ? size.width * 0.45 : -size.width * 0.45)
                            .opacity(reduceMotion ? 0 : 1)
                    }
                    .frame(width: size.width, height: size.height)
                    .blendMode(.softLight)
                    .mask { HeroCardOutline() }
                    .allowsHitTesting(false)
                }
            }
            .rotation3DEffect(.degrees(lean.x), axis: (x: 1, y: 0, z: 0), perspective: 0.5)
            .rotation3DEffect(.degrees(lean.y), axis: (x: 0, y: 1, z: 0), perspective: 0.5)
            .animation(.spring(duration: 0.35, bounce: 0), value: tilt.roll)
            .animation(.spring(duration: 0.35, bounce: 0), value: tilt.pitch)
            .offset(y: afloat ? -width * 0.008 : 0).rotationEffect(.degrees(afloat ? 0.45 : 0))
            .onAppear {
                guard !reduceMotion else { return }
                tilt.start()
                withAnimation(.easeInOut(duration: 3.25).repeatForever(autoreverses: true)) { afloat = true }
                withAnimation(.easeInOut(duration: 2.2).delay(5.8).repeatForever(autoreverses: false)) { glint = true }
            }
            .onDisappear { tilt.stop() }
    }
}

/// The title (D179): a greeting by the hour, then "Catch 5" rising out of a blur with one sweep of gold across it.
struct HomeTitle: View {
    let width: Double
    var guest: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var risen = false
    @State private var swept = false

    var body: some View {
        let font = Font.system(size: min(60, width * 0.15), weight: .bold, design: .serif)
        VStack(spacing: 4) {
            Text(HomeMotion.greeting(hour: Calendar.current.component(.hour, from: Date()), guest: guest))
                .font(.system(.footnote, design: .serif).weight(.semibold)).italic().opacity(0.8)
                .opacity(risen ? 1 : 0).offset(y: risen ? 0 : 6)
                .animation(.easeOut(duration: 0.8).delay(0.55), value: risen)
            Text("Catch 5").font(font)
                .overlay {
                    GeometryReader { geometry in
                        LinearGradient(colors: [.clear, Color(red: 1, green: 0.98, blue: 0.94), Color(red: 0.95, green: 0.83, blue: 0.60),
                                                Color(red: 1, green: 0.98, blue: 0.94), .clear], startPoint: .leading, endPoint: .trailing)
                            .frame(width: geometry.size.width * 0.45)
                            .offset(x: swept ? geometry.size.width : -geometry.size.width * 0.45)
                            .animation(.easeInOut(duration: 1.7).delay(0.95), value: swept)
                    }
                    .mask { Text("Catch 5").font(font) }
                    .allowsHitTesting(false).accessibilityHidden(true)
                }
                .opacity(risen ? 1 : 0).offset(y: risen ? 0 : 10).blur(radius: risen ? 0 : 6)
                .animation(.timingCurve(0.2, 0.8, 0.2, 1, duration: 1.05), value: risen)
            Text("A FAMILY CARD GAME").font(.system(.footnote, design: .serif).weight(.semibold)).tracking(3.5)
                .opacity(risen ? 1 : 0).offset(y: risen ? 0 : 6)
                .animation(.easeOut(duration: 0.8).delay(0.35), value: risen)
        }
        .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1.5)
        .transaction { if reduceMotion { $0.animation = nil } }
        .onAppear { risen = true; swept = !reduceMotion }
        .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)
    }
}

/// Warm light drifting over the cloth and breathing on the wood (D179).
struct HomeGlow: View {
    let width: Double
    let height: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var moved = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Ellipse().fill(RadialGradient(colors: [Color(red: 1, green: 0.96, blue: 0.86).opacity(0.22), .clear], center: .center, startRadius: 0, endRadius: width * 0.42))
                .frame(width: width * 0.85, height: height * 0.34)
                .scaleEffect(moved ? 1.15 : 1).offset(x: -width * 0.35 + (moved ? width * 0.66 : 0), y: -height * 0.04)
                .blendMode(.softLight)
                .animation(reduceMotion ? nil : .easeInOut(duration: 17).repeatForever(autoreverses: true), value: moved)
            Ellipse().fill(RadialGradient(colors: [Color(red: 1, green: 0.75, blue: 0.43).opacity(0.26), .clear], center: .center, startRadius: 0, endRadius: width * 0.45))
                .frame(width: width * 0.9, height: height * 0.46)
                .scaleEffect(moved ? 1.06 : 0.95).opacity(moved ? 1 : 0.45)
                .offset(x: width * 0.05 + (moved ? width * 0.054 : -width * 0.054), y: height * 0.30 - (moved ? height * 0.014 : 0))
                .blendMode(.overlay)
                .animation(reduceMotion ? nil : .easeInOut(duration: 11).repeatForever(autoreverses: true), value: moved)
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false).accessibilityHidden(true)
        .onAppear { if !reduceMotion { moved = true } }
    }
}

/// One tuft of five blades, drawn in a 60 by 50 box and swaying from its root.
struct GrassTuft: View {
    let width: Double
    let delay: Double
    let flipped: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var swayed = false

    private static let blades: [(start: (Double, Double), up: [(Double, Double)], down: [(Double, Double)], colour: Color)] = [
        ((14, 50), [(13, 36), (9, 24), (2, 14)], [(11, 21), (17, 32), (19, 50)], Color(red: 0.37, green: 0.42, blue: 0.23)),
        ((22, 50), [(22, 33), (25, 19), (32, 4)], [(30, 20), (29, 34), (28, 50)], Color(red: 0.49, green: 0.53, blue: 0.28)),
        ((30, 50), [(33, 36), (40, 25), (52, 17)], [(43, 27), (38, 38), (36, 50)], Color(red: 0.42, green: 0.47, blue: 0.25)),
        ((38, 50), [(39, 40), (43, 32), (51, 26)], [(46, 34), (43, 41), (43, 50)], Color(red: 0.59, green: 0.63, blue: 0.35)),
        ((8, 50), [(10, 42), (9, 35), (5, 28)], [(11, 34), (14, 41), (13, 50)], Color(red: 0.54, green: 0.58, blue: 0.31)),
    ]

    var body: some View {
        Canvas { context, size in
            let scale = size.width / 60
            func point(_ p: (Double, Double)) -> CGPoint { CGPoint(x: p.0 * scale, y: p.1 * scale) }
            for blade in Self.blades {
                var path = Path()
                path.move(to: point(blade.start))
                path.addCurve(to: point(blade.up[2]), control1: point(blade.up[0]), control2: point(blade.up[1]))
                path.addCurve(to: point(blade.down[2]), control1: point(blade.down[0]), control2: point(blade.down[1]))
                path.closeSubpath()
                context.fill(path, with: .color(blade.colour))
            }
        }
        .frame(width: width, height: width * 50 / 60)
        .scaleEffect(x: flipped ? -1 : 1)
        .rotationEffect(.degrees(swayed ? 5 : -4), anchor: .bottom)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 4.4).delay(delay).repeatForever(autoreverses: true)) { swayed = true }
        }
        .accessibilityHidden(true)
    }
}

/// Tufts of grass in the bottom corners, moving in a breeze (D179). `height` is the whole screen's, to its bottom edge.
struct GrassBreeze: View {
    let width: Double
    let height: Double

    private static let tufts: [(left: Double, bottom: Double, wide: Double, delay: Double, flipped: Bool)] = [
        (-0.01, 0.076, 0.09, 0, false), (0.045, 0.086, 0.065, 0.8, true), (0.925, 0.084, 0.08, 0.4, true),
        (0.965, 0.066, 0.06, 1.3, false), (0.01, -0.006, 0.07, 1.7, false), (0.93, -0.008, 0.075, 0.2, true),
    ]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(Self.tufts.enumerated()), id: \.offset) { _, tuft in
                let wide = width * tuft.wide, tall = wide * 50 / 60
                GrassTuft(width: wide, delay: tuft.delay, flipped: tuft.flipped)
                    .position(x: width * tuft.left + wide / 2, y: height - height * tuft.bottom - tall / 2)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .allowsHitTesting(false)
    }
}

/// One card flying from the deck to its place on the blanket, then gone.
private struct DealtCard: View {
    let from: CGPoint
    let to: CGPoint
    let turn: Double
    let delay: Double
    let card: Double

    @State private var flown = false
    @State private var gone = false

    var body: some View {
        RoundedRectangle(cornerRadius: card * 0.14, style: .continuous).fill(Color(red: 0.95, green: 0.90, blue: 0.78))
            .overlay(RoundedRectangle(cornerRadius: card * 0.08, style: .continuous).fill(Color(red: 0.55, green: 0.13, blue: 0.13)).padding(card * 0.1))
            .frame(width: card, height: card * 1.4)
            .shadow(color: .black.opacity(0.4), radius: 3, y: 3)
            .rotationEffect(.degrees(flown ? turn + 360 : -10)).scaleEffect(flown ? 0.8 : 1)
            .opacity(gone ? 0 : 1)
            .position(flown ? to : from)
            .onAppear {
                withAnimation(.timingCurve(0.25, 0.8, 0.3, 1, duration: 0.62).delay(delay)) { flown = true }
                withAnimation(.easeIn(duration: 0.2).delay(delay + 0.85)) { gone = true }
            }
    }
}

/// Play's deal (D179): a card from the deck to each of the five on the blanket. `origin` and `size` are the family
/// picture's place on the screen.
struct DealLayer: View {
    let origin: CGPoint
    let size: CGSize

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(Array(HomeMotion.seats.enumerated()), id: \.offset) { index, seat in
                DealtCard(from: CGPoint(x: origin.x + size.width * HomeMotion.deck.x, y: origin.y + size.height * HomeMotion.deck.y),
                          to: CGPoint(x: origin.x + size.width * seat.x, y: origin.y + size.height * seat.y),
                          turn: seat.turn, delay: Double(index) * HomeMotion.dealStagger, card: size.width * 0.075)
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
