import SwiftUI

/// A sketch of a seat as a cut-paper bust: flat shapes, no face, a darker tone for shadow, and its own curved hem for
/// a floor, so it needs no disc or ring. It is a trial of the style on one character (curly hair, mortarboard,
/// collared shirt) and is not on the table yet.
struct PaperBust: View {
    let portrait: Portrait
    let size: Double

    /// The bust is a little taller than it is wide.
    static let aspect = 1.16

    var body: some View {
        Canvas { context, canvas in
            let s = canvas.width
            func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func blob(_ x: Double, _ y: Double, _ r: Double) -> Path {
                Path(ellipseIn: CGRect(x: (x - r) * s, y: (y - r) * s, width: r * 2 * s, height: r * 2 * s))
            }
            func shape(_ points: [(Double, Double)]) -> Path {
                var path = Path()
                path.addLines(points.map { p($0.0, $0.1) })
                path.closeSubpath()
                return path
            }
            let skin = Theme.Portrait.color(portrait.skin), hair = Theme.Portrait.color(portrait.hairColor)
            let shirt = Theme.Portrait.color(portrait.shirt), dark = Theme.Portrait.accessory
            let shade = GraphicsContext.Shading.color(.black.opacity(0.26))

            // Hair behind the head: a cloud of curls.
            for curl in [(0.36, 0.33, 0.15), (0.30, 0.45, 0.13), (0.44, 0.24, 0.14), (0.57, 0.22, 0.13),
                         (0.35, 0.55, 0.10), (0.67, 0.27, 0.10), (0.26, 0.36, 0.10)] {
                context.fill(blob(curl.0, curl.1, curl.2), with: .color(hair))
            }

            // Neck, down into the open collar, with the chin's shadow across it.
            let neck = shape([(0.43, 0.52), (0.59, 0.58), (0.585, 0.73), (0.49, 0.88), (0.415, 0.73)])
            context.fill(neck, with: .color(skin))
            context.fill(shape([(0.43, 0.52), (0.59, 0.60), (0.585, 0.69), (0.425, 0.63)]), with: shade)

            // Shoulders: one mound of shirt, cut along the bottom in a curve.
            var shoulders = Path()
            shoulders.move(to: p(0.05, 1.04))
            shoulders.addCurve(to: p(0.40, 0.72), control1: p(0.06, 0.84), control2: p(0.22, 0.76))
            shoulders.addLine(to: p(0.49, 0.88))
            shoulders.addLine(to: p(0.60, 0.72))
            shoulders.addCurve(to: p(0.97, 1.04), control1: p(0.78, 0.76), control2: p(0.96, 0.84))
            shoulders.addQuadCurve(to: p(0.05, 1.04), control: p(0.51, 1.17))
            shoulders.closeSubpath()
            context.fill(shoulders, with: .color(shirt))
            // Two folds, each a sliver of shadow.
            for fold in [(0.19, 0.84, 0.25, 0.95, 0.24, 1.07, 0.21, 0.95), (0.82, 0.84, 0.75, 0.95, 0.77, 1.07, 0.80, 0.95)] {
                var sliver = Path()
                sliver.move(to: p(fold.0, fold.1))
                sliver.addQuadCurve(to: p(fold.4, fold.5), control: p(fold.2, fold.3))
                sliver.addQuadCurve(to: p(fold.0, fold.1), control: p(fold.6, fold.7))
                context.fill(sliver, with: shade)
            }

            // Collar points.
            context.fill(shape([(0.40, 0.69), (0.485, 0.87), (0.34, 0.88), (0.28, 0.77)]), with: .color(Theme.Portrait.collar))
            context.fill(shape([(0.60, 0.69), (0.495, 0.87), (0.65, 0.90), (0.72, 0.78)]), with: .color(Theme.Portrait.collar))

            // The head: one flat shape, turned a little away and up. No face.
            let head = Path(ellipseIn: CGRect(x: -0.17 * s, y: -0.215 * s, width: 0.34 * s, height: 0.43 * s))
                .applying(CGAffineTransform(rotationAngle: -0.2).concatenating(CGAffineTransform(translationX: 0.555 * s, y: 0.42 * s)))
            context.fill(head, with: .color(skin))

            // Curls that fall over the temple, then the ear in front of them.
            for curl in [(0.42, 0.31, 0.07), (0.40, 0.40, 0.06), (0.50, 0.25, 0.07)] {
                context.fill(blob(curl.0, curl.1, curl.2), with: .color(hair))
            }
            let ear = Path(ellipseIn: CGRect(x: 0.405 * s, y: 0.42 * s, width: 0.07 * s, height: 0.10 * s))
            context.fill(ear, with: .color(skin))
            context.fill(Path(ellipseIn: CGRect(x: 0.425 * s, y: 0.445 * s, width: 0.035 * s, height: 0.055 * s)), with: shade)

            // The mortarboard: a cap, a board seen from below and to one side, and its tassel.
            if portrait.hat == .mortarboard {
                let cap = Path(ellipseIn: CGRect(x: -0.18 * s, y: -0.085 * s, width: 0.36 * s, height: 0.17 * s))
                    .applying(CGAffineTransform(rotationAngle: -0.2).concatenating(CGAffineTransform(translationX: 0.57 * s, y: 0.245 * s)))
                context.fill(cap, with: .color(dark))
                context.fill(shape([(0.25, 0.15), (0.60, 0.05), (0.90, 0.16), (0.55, 0.27)]), with: .color(dark))
                context.fill(shape([(0.25, 0.15), (0.55, 0.27), (0.90, 0.16), (0.90, 0.18), (0.55, 0.295), (0.25, 0.17)]), with: shade)
                var cord = Path()
                cord.addLines([p(0.585, 0.155), p(0.83, 0.185), p(0.845, 0.31)])
                context.stroke(cord, with: .color(Theme.Portrait.tassel),
                               style: StrokeStyle(lineWidth: max(1, 0.02 * s), lineCap: .round, lineJoin: .round))
                context.fill(Path(roundedRect: CGRect(x: 0.82 * s, y: 0.30 * s, width: 0.05 * s, height: 0.09 * s), cornerRadius: 0.02 * s),
                             with: .color(Theme.Portrait.tassel))
            }
        }
        .frame(width: size, height: size * Self.aspect)
        .accessibilityHidden(true)
    }
}
