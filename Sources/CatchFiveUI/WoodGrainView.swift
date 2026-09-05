import SwiftUI

/// An oak table top drawn once from a fixed seed: a warm base, tonal bands, several hundred wavy
/// grain lines and a vignette. No image asset, so the hand-built simulator bundle needs nothing extra.
/// `Theme.Wood.grainRunsHorizontally` picks the grain's direction; everything below is written in
/// terms of "along" the grain and "across" it.
struct WoodGrainView: View {
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let horizontal = Theme.Wood.grainRunsHorizontally
            let along = horizontal ? Double(size.width) : Double(size.height)
            let across = horizontal ? Double(size.height) : Double(size.width)
            func point(_ a: Double, _ c: Double) -> CGPoint { horizontal ? CGPoint(x: a, y: c) : CGPoint(x: c, y: a) }
            func band(at c: Double, width w: Double) -> Path {
                horizontal ? Path(CGRect(x: -10, y: c, width: along + 20, height: w))
                           : Path(CGRect(x: c, y: -10, width: w, height: along + 20))
            }

            let bounds = Path(CGRect(origin: .zero, size: size))
            context.fill(bounds, with: .linearGradient(
                Gradient(colors: [Theme.Wood.light, Theme.Wood.base, Theme.Wood.dark]),
                startPoint: .zero, endPoint: point(along * 0.4, across)))

            var random = GrainRandom(seed: Theme.Wood.seed)
            // Broad tonal bands, the way a board lightens and darkens across its width.
            for _ in 0..<Theme.Wood.bandCount {
                let c = random.next(in: -40...across)
                let width = random.next(in: 18...70)
                let light = random.next(in: 0...1) < 0.5
                context.fill(band(at: c, width: width),
                             with: .color((light ? Theme.Wood.light : Theme.Wood.dark).opacity(random.next(in: 0.10...0.28))))
            }
            // Grain: thin lines running the length of the board at uneven spacing, each with its own slow
            // wave; a few swing wide, the way figure shows in a cut board.
            var c0 = -6.0
            while c0 < across + 6 {
                c0 += random.next(in: Theme.Wood.grainSpacing)
                let wide = random.next(in: 0...1) < 0.12
                let amplitude = wide ? random.next(in: 10...26) : random.next(in: 1...7)
                let frequency = wide ? random.next(in: 0.002...0.006) : random.next(in: 0.004...0.014)
                let phase = random.next(in: 0...(2 * .pi))
                let ripple = random.next(in: 0.2...1.4)
                var path = Path()
                path.move(to: point(-4, c0))
                var a = 0.0
                while a < along + 8 {
                    a += 8
                    let c = c0 + amplitude * sin(a * frequency + phase) + ripple * sin(a * 0.09 + phase * 3)
                    path.addLine(to: point(a, c))
                }
                let light = random.next(in: 0...1) < 0.45
                let strong = random.next(in: 0...1) < 0.15
                let alpha = strong ? random.next(in: 0.14...0.24) : random.next(in: 0.03...0.10)
                context.stroke(path, with: .color((light ? Theme.Wood.streakLight : Theme.Wood.streakDark).opacity(alpha)),
                               lineWidth: strong ? random.next(in: 1.2...2.4) : random.next(in: 0.5...1.4))
            }
            // Vignette: the edges fall away so the cards and the pile read as the lit centre.
            context.fill(bounds, with: .radialGradient(
                Gradient(colors: [.clear, .black.opacity(0.5)]),
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
