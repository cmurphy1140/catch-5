import SwiftUI

/// The timing of the dog's run (D182), as plain numbers so it is tested without a screen.
enum GuestDogRunMotion {
    /// How long each picture stands, and how long the last one, her face close up, is held.
    static let step = 0.21, hold = 1.0
    /// The share of each step, at its end, spent fading into the next picture.
    static let fade = 0.45

    static func duration(frames: Int) -> Double { Double(max(0, frames)) * step + hold }

    /// Which picture is up at a moment, and how far the next has faded in over it (0 to 1). The last picture stays.
    static func frame(at time: Double, frames: Int) -> (index: Int, blend: Double) {
        guard frames > 0 else { return (0, 0) }
        let slot = max(0, time) / step
        let index = min(frames - 1, Int(slot))
        guard index < frames - 1 else { return (frames - 1, 0) }
        let within = slot - Double(index)
        return (index, max(0, (within - (1 - fade)) / fade))
    }
}

/// Her dog bounding up through the snow: the build's own pictures played as a flipbook, each fading into the next.
struct GuestDogRun: View {
    let frames: [Image]
    @State private var began = Date()

    /// Set once the run has played by itself, so later visits open straight on the swans.
    static let seenKey = "guestDogRunSeen"

    /// The run's pictures, `GuestDogRun1` onward, when the build carries at least two.
    static var carried: [Image]? {
        var pictures: [Image] = []
        while let next = SeatArt.named("GuestDogRun\(pictures.count + 1)") { pictures.append(next) }
        return pictures.count >= 2 ? pictures : nil
    }

    var body: some View {
        TimelineView(.animation) { timeline in
            let now = GuestDogRunMotion.frame(at: timeline.date.timeIntervalSince(began), frames: frames.count)
            ZStack {
                frames[now.index].resizable().scaledToFit()
                if now.blend > 0, frames.indices.contains(now.index + 1) {
                    frames[now.index + 1].resizable().scaledToFit().opacity(now.blend)
                }
            }
        }
        // The picture's top and bottom melt into the felt, so it reads as a window, not a card.
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                                   .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityLabel("A golden retriever running up through the snow")
        .onAppear { began = Date() }
    }
}
