import SwiftUI

/// A face drawn from a `Portrait` recipe: shoulders, head, hair, one feature, one hat, inside an ivory-ringed disc.
/// Every measurement is a fraction of `size`, so the same view serves 28 pt seat tiles and 72 pt pickers.
struct PortraitView: View {
    let portrait: Portrait
    let size: Double
    /// The mood on the face; the default keeps pickers and cards calm.
    var expression: Portrait.Expression = .neutral
    /// On the table the face pops out of its disc (N49): the character is drawn larger and higher, the body
    /// stays clipped to the disc, and the head rises over its top edge, outside the view's frame. The seat
    /// reserves `Theme.Table.portraitHeadroom` above the disc for it.
    var popsOut = false
    /// Draws only the popped head, with no disc, so a seat can lay it over its rings and keep the head in front.
    var headOnly = false
    /// The disc's rim. On the table it says which side the seat is on (D97); elsewhere it is the usual light ring.
    var rim: Color = .ivory.opacity(0.7)
    var rimWidth: Double? = nil
    /// Cut out of its disc (D124): no green fill and no rim, only the figure, for the menu's paper card.
    var cutOut = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if headOnly {
            poppedHead
        } else {
            ZStack {
                Circle().fill(cutOut ? Color.clear : Theme.Portrait.disc)
                ZStack {
                    shoulders
                    headParts
                }
                .scaleEffect(popsOut ? Theme.Portrait.popScale : 1)
                .offset(y: popsOut ? -size * Theme.Portrait.popRise : 0)
            }
            .animation(reduceMotion ? nil : Theme.Motion.overlay, value: expression)
            .frame(width: size, height: size)
            .clipShape(Circle())
            .overlay(Circle().stroke(cutOut ? Color.clear : rim, lineWidth: rimWidth ?? max(1, size * 0.03)))
            .overlay { if popsOut { poppedHead } }
            .accessibilityHidden(true)
        }
    }

    /// Everything above the shoulders, back to front.
    private var headParts: some View {
        ZStack {
            hairBack
            head
            face
            feature
            hairFront
            hat
        }
    }

    /// The head again, unclipped, over the upper half of the disc and above it: the part that pops out.
    private var poppedHead: some View {
        headParts
            .scaleEffect(Theme.Portrait.popScale)
            .offset(y: -size * Theme.Portrait.popRise)
            .animation(reduceMotion ? nil : Theme.Motion.overlay, value: expression)
            .frame(width: size, height: size)
            .mask(alignment: .top) { Rectangle().frame(width: size * 2, height: size * 1.5).offset(y: -size) }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    /// Tops of the head and of the tallest hat, as fractions of `size` above the disc's centre, before popping.
    nonisolated static let headTop = 0.29
    nonisolated static let tallestTop = 0.39

    /// How far, as a fraction of `size`, a part whose top sits `top` above the centre rises over the disc's
    /// top edge once popped out.
    nonisolated static func popOverflow(top: Double) -> Double {
        top * Theme.Portrait.popScale + Theme.Portrait.popRise - 0.5
    }

    // MARK: Face

    /// Two eyes, two brows and a mouth, each a fraction of the head, moved by the expression alone.
    private var face: some View {
        let ink = Theme.Portrait.accessory
        let eyeY = -size * 0.06
        let eyeDX = size * 0.08
        let lookAside = expression == .thinking ? size * 0.02 : 0
        let eyeSize = expression == .surprised ? 0.05 : 0.035
        let browTilt: Double = switch expression {
        case .thinking: -12
        case .rueful, .dismayed: 14
        case .triumphant: -6
        default: 0
        }
        let browLift: Double = switch expression {
        case .triumphant, .pleased: -size * 0.02
        case .dismayed: size * 0.005
        case .surprised: -size * 0.035
        default: 0
        }
        let mouthCurve: Double = switch expression {   // positive smiles, negative frowns
        case .pleased: 0.5
        case .triumphant: 1
        case .rueful: -0.4
        case .dismayed: -0.9
        default: 0
        }
        return ZStack {
            ForEach([-1.0, 1.0], id: \.self) { side in
                Circle().fill(ink).frame(width: size * eyeSize, height: size * eyeSize)
                    .offset(x: side * eyeDX + lookAside, y: eyeY)
                Capsule().fill(ink).frame(width: size * 0.09, height: max(1, size * 0.014))
                    .rotationEffect(.degrees(browTilt * side * -1))
                    .offset(x: side * eyeDX, y: eyeY - size * 0.055 + browLift)
            }
            Mouth(curve: mouthCurve)
                .stroke(ink, style: StrokeStyle(lineWidth: max(1, size * 0.018), lineCap: .round))
                .frame(width: size * 0.14, height: size * 0.05)
                .offset(y: size * 0.1)
                .opacity(expression == .surprised ? 0 : 1)
            // Surprise: a small round "oh" in place of the line.
            Ellipse()
                .stroke(ink, lineWidth: max(1, size * 0.018))
                .frame(width: size * 0.07, height: size * 0.09)
                .offset(y: size * 0.11)
                .opacity(expression == .surprised ? 1 : 0)
        }
    }

    /// A mouth whose bend animates: `curve` runs from −1 (frown) through 0 (flat) to 1 (grin).
    private struct Mouth: Shape {
        var curve: Double
        var animatableData: Double { get { curve } set { curve = newValue } }
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.move(to: CGPoint(x: rect.minX, y: rect.midY))
            path.addQuadCurve(to: CGPoint(x: rect.maxX, y: rect.midY),
                              control: CGPoint(x: rect.midX, y: rect.midY + curve * rect.height * 1.6))
            return path
        }
    }

    // MARK: Parts

    private var shoulders: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Theme.Portrait.color(portrait.shirt))
                .frame(width: size * 0.78, height: size * 0.5)
                .offset(y: size * 0.5)
            neckline
        }
    }

    /// The scholars' shirts show at the neck, above where a name sticker sits: an ivory V under the tweed
    /// jacket and the cardigan, two collar points on the oxford.
    @ViewBuilder private var neckline: some View {
        switch portrait.shirt {
        case .tweed, .burgundy:
            Outline(points: [(-0.1, 0.22), (0.1, 0.22), (0, 0.37)]).fill(Theme.Portrait.collar)
                .frame(width: size, height: size)
        case .oxford:
            ForEach([-1.0, 1.0], id: \.self) { side in
                Outline(points: [(side * 0.02, 0.24), (side * 0.13, 0.22), (side * 0.07, 0.34)]).fill(Theme.Portrait.collar)
                    .frame(width: size, height: size)
            }
        case .plum, .olive, .teal, .rust, .navy, .mustard:
            EmptyView()
        }
    }

    /// A closed or open run of points, each a fraction of the frame measured from its centre.
    private struct Outline: Shape {
        let points: [(Double, Double)]
        var closed = true
        func path(in rect: CGRect) -> Path {
            var path = Path()
            path.addLines(points.map { CGPoint(x: rect.midX + $0.0 * rect.width, y: rect.midY + $0.1 * rect.height) })
            if closed { path.closeSubpath() }
            return path
        }
    }

    private var head: some View {
        Ellipse()
            .fill(Theme.Portrait.color(portrait.skin))
            .frame(width: size * 0.46, height: size * 0.54)
            .offset(y: -size * 0.02)
    }

    /// Hair drawn behind the head: the bob's sides and the curly mass.
    @ViewBuilder private var hairBack: some View {
        let color = Theme.Portrait.color(portrait.hairColor)
        switch portrait.hair {
        case .bob:
            RoundedRectangle(cornerRadius: size * 0.16, style: .continuous)
                .fill(color).frame(width: size * 0.56, height: size * 0.6).offset(y: -size * 0.02)
        case .curly:
            Circle().fill(color).frame(width: size * 0.6, height: size * 0.6).offset(y: -size * 0.06)
        case .short, .bald:
            EmptyView()
        }
    }

    /// Hair drawn over the head: the short cut's cap.
    @ViewBuilder private var hairFront: some View {
        if portrait.hair == .short {
            Ellipse()
                .fill(Theme.Portrait.color(portrait.hairColor))
                .frame(width: size * 0.48, height: size * 0.24)
                .offset(y: -size * 0.24)
        }
    }

    @ViewBuilder private var feature: some View {
        switch portrait.feature {
        case .none:
            EmptyView()
        case .glasses:
            HStack(spacing: size * 0.02) {
                Circle().stroke(Theme.Portrait.accessory, lineWidth: max(1, size * 0.025)).frame(width: size * 0.15, height: size * 0.15)
                Circle().stroke(Theme.Portrait.accessory, lineWidth: max(1, size * 0.025)).frame(width: size * 0.15, height: size * 0.15)
            }.offset(y: -size * 0.03)
        case .moustache:
            Capsule().fill(Theme.Portrait.color(portrait.hairColor))
                .frame(width: size * 0.2, height: size * 0.05).offset(y: size * 0.05)
        case .freckles:
            HStack(spacing: size * 0.04) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle().fill(Theme.Portrait.accessory.opacity(0.5)).frame(width: size * 0.03, height: size * 0.03)
                }
            }.offset(y: size * 0.05)
        case .spectacles:
            // Round reading spectacles: smaller, finer and lower than `glasses`, with a glint in the lenses and
            // arms running back to the ears.
            let rim = max(1, size * 0.016)
            ZStack {
                ForEach([-1.0, 1.0], id: \.self) { side in
                    Circle().fill(Color.ivory.opacity(0.3)).frame(width: size * 0.12, height: size * 0.12)
                        .overlay(Circle().stroke(Theme.Portrait.accessory, lineWidth: rim))
                        .offset(x: side * size * 0.08)
                }
                Outline(points: [(-0.02, -0.005), (0, -0.015), (0.02, -0.005)], closed: false)
                    .stroke(Theme.Portrait.accessory, lineWidth: rim)
                    .frame(width: size, height: size)
                Outline(points: [(-0.14, 0), (-0.23, -0.02)], closed: false).stroke(Theme.Portrait.accessory, lineWidth: rim)
                    .frame(width: size, height: size)
                Outline(points: [(0.14, 0), (0.23, -0.02)], closed: false).stroke(Theme.Portrait.accessory, lineWidth: rim)
                    .frame(width: size, height: size)
            }.offset(y: -size * 0.05)
        }
    }

    @ViewBuilder private var hat: some View {
        switch portrait.hat {
        case .none:
            EmptyView()
        case .beanie:
            RoundedRectangle(cornerRadius: size * 0.14, style: .continuous)
                .fill(Theme.Portrait.accessory)
                .frame(width: size * 0.5, height: size * 0.26).offset(y: -size * 0.26)
        case .cap:
            ZStack {
                Ellipse().fill(Theme.Portrait.accessory).frame(width: size * 0.5, height: size * 0.22).offset(y: -size * 0.26)
                Capsule().fill(Theme.Portrait.accessory).frame(width: size * 0.62, height: size * 0.07).offset(y: -size * 0.18)
            }
        case .flower:
            Image(systemName: "leaf.fill")
                .resizable().scaledToFit()
                .foregroundStyle(Theme.Portrait.blossom)
                .frame(width: size * 0.2, height: size * 0.2)
                .rotationEffect(.degrees(-30))
                .offset(x: size * 0.18, y: -size * 0.24)
        case .mortarboard:
            // A skullcap under a flat square board seen from the front, its tassel hanging off the right corner.
            // The board's top stays at `tallestTop`, so a popped head still fits the seat's headroom.
            ZStack {
                Ellipse().fill(Theme.Portrait.accessory).frame(width: size * 0.46, height: size * 0.2).offset(y: -size * 0.24)
                Outline(points: [(-0.33, -0.33), (0, -0.39), (0.33, -0.33), (0, -0.27)]).fill(Theme.Portrait.accessory)
                    .frame(width: size, height: size)
                Outline(points: [(0, -0.33), (0.27, -0.32), (0.28, -0.19)], closed: false)
                    .stroke(Theme.Portrait.tassel, style: StrokeStyle(lineWidth: max(1, size * 0.02), lineCap: .round, lineJoin: .round))
                    .frame(width: size, height: size)
                Capsule().fill(Theme.Portrait.tassel).frame(width: size * 0.05, height: size * 0.09).offset(x: size * 0.28, y: -size * 0.17)
            }
        }
    }
}
