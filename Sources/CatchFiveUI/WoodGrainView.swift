import SwiftUI

/// A walnut table top drawn once from a fixed seed: a warm base, tonal bands, several hundred wavy
/// grain lines and a vignette. No image asset, so the hand-built simulator bundle needs nothing extra.
struct WoodGrainView: View {
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let bounds = Path(CGRect(origin: .zero, size: size))
            context.fill(bounds, with: .linearGradient(
                Gradient(colors: [Theme.Wood.light, Theme.Wood.base, Theme.Wood.dark]),
                startPoint: .zero, endPoint: CGPoint(x: size.width * 0.4, y: size.height)))

            var random = GrainRandom(seed: Theme.Wood.seed)
            // Broad tonal bands, the way a board lightens and darkens across its width.
            for _ in 0..<Theme.Wood.bandCount {
                let x = random.next(in: -40...Double(size.width))
                let width = random.next(in: 18...70)
                let band = Path(CGRect(x: x, y: -10, width: width, height: size.height + 20))
                let light = random.next(in: 0...1) < 0.5
                context.fill(band, with: .color((light ? Theme.Wood.light : Theme.Wood.dark).opacity(random.next(in: 0.10...0.28))))
            }
            // Grain: thin lines running the length of the table at uneven spacing, each with its own slow
            // wave; a few swing wide, the way figure shows in a cut board.
            var x0 = -6.0
            while x0 < Double(size.width) + 6 {
                x0 += random.next(in: Theme.Wood.grainSpacing)
                let wide = random.next(in: 0...1) < 0.12
                let amplitude = wide ? random.next(in: 10...26) : random.next(in: 1...7)
                let frequency = wide ? random.next(in: 0.002...0.006) : random.next(in: 0.004...0.014)
                let phase = random.next(in: 0...(2 * .pi))
                let ripple = random.next(in: 0.2...1.4)
                var path = Path()
                path.move(to: CGPoint(x: x0, y: -4))
                var y = 0.0
                while y < size.height + 8 {
                    y += 8
                    let x = x0 + amplitude * sin(y * frequency + phase) + ripple * sin(y * 0.09 + phase * 3)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
                let light = random.next(in: 0...1) < 0.45
                let strong = random.next(in: 0...1) < 0.15
                let alpha = strong ? random.next(in: 0.14...0.24) : random.next(in: 0.03...0.10)
                context.stroke(path, with: .color((light ? Theme.Wood.streakLight : Theme.Wood.streakDark).opacity(alpha)),
                               lineWidth: strong ? random.next(in: 1.2...2.4) : random.next(in: 0.5...1.4))
            }
            // Vignette: the edges fall away so the cards and the pile read as the lit centre.
            context.fill(bounds, with: .radialGradient(
                Gradient(colors: [.clear, .black.opacity(0.55)]),
                center: CGPoint(x: size.width / 2, y: size.height * 0.45),
                startRadius: size.width * 0.35, endRadius: size.height * 0.8))
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// A small linear congruential generator so the grain is the same on every launch.
struct GrainRandom {
    private var state: UInt64
    init(seed: UInt64) { state = seed &* 6364136223846793005 &+ 1442695040888963407 }
    mutating func next() -> Double {
        state = state &* 6364136223846793005 &+ 1442695040888963407
        return Double(state >> 11) / Double(1 << 53)
    }
    mutating func next(in range: ClosedRange<Double>) -> Double {
        range.lowerBound + (range.upperBound - range.lowerBound) * next()
    }
}
