import SwiftUI

/// The timing of the dog's run, as plain numbers so it is tested without a screen.
enum GuestDogRunMotion {
    /// Fallback timing for a build carrying a different number of running pictures.
    static let step = 0.21, hold = 1.0
    static let fade = 0.45
    static let introHold = 0.56
    /// The approved eight running poses, ending with the snow on her nose.
    static let approvedRunHolds = [0.16, 0.20, 0.12, 0.20, 0.12, 0.16, 0.20, 0.90]

    static func duration(frames: Int) -> Double { Double(max(0, frames)) * step + hold }

    /// Legacy uniform timing remains the fallback for other frame counts.
    static func frame(at time: Double, frames: Int) -> (index: Int, blend: Double) {
        guard frames > 0 else { return (0, 0) }
        let slot = max(0, time) / step
        let index = min(frames - 1, Int(slot))
        guard index < frames - 1 else { return (frames - 1, 0) }
        let within = slot - Double(index)
        return (index, max(0, (within - (1 - fade)) / fade))
    }

    /// The optional seated-in-snow opening precedes the existing running pictures.
    static func holds(runningFrames: Int, intro: Bool) -> [Double] {
        let count = max(0, runningFrames)
        var result = count == approvedRunHolds.count ? approvedRunHolds
            : (0..<count).map { $0 == count - 1 ? step + hold : step }
        if intro { result.insert(introHold, at: 0) }
        return result
    }

    static func frame(at time: Double, holds: [Double]) -> (index: Int, blend: Double) {
        guard !holds.isEmpty else { return (0, 0) }
        var remaining = max(0, time)
        for (index, duration) in holds.enumerated() {
            if index == holds.count - 1 { return (index, 0) }
            if remaining < duration {
                let within = remaining / max(duration, Double.leastNonzeroMagnitude)
                return (index, min(1, max(0, (within - (1 - fade)) / fade)))
            }
            remaining -= duration
        }
        return (holds.count - 1, 0)
    }
}

/// Her dog bounding through the snow. Reduce Motion keeps the final snowy-nose picture still.
struct GuestDogRun: View {
    struct Frames {
        let pictures: [Image]
        let holds: [Double]
        var duration: Double { holds.reduce(0, +) }
    }

    let frames: Frames
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var began = Date()

    static let seenKey = "guestDogRunSeen"

    /// Existing running pictures remain optional, as does the recovered establishing still.
    static var carried: Frames? {
        var pictures: [Image] = []
        while let next = SeatArt.named("GuestDogRun\(pictures.count + 1)") { pictures.append(next) }
        guard pictures.count >= 2 else { return nil }
        let intro = SeatArt.named("GuestDogRunIntro")
        let holds = GuestDogRunMotion.holds(runningFrames: pictures.count, intro: intro != nil)
        if let intro { pictures.insert(intro, at: 0) }
        return Frames(pictures: pictures, holds: holds)
    }

    var body: some View {
        Group {
            if reduceMotion, let last = frames.pictures.last {
                last.resizable().scaledToFit()
            } else if !frames.pictures.isEmpty {
                TimelineView(.animation) { timeline in
                    let now = GuestDogRunMotion.frame(at: timeline.date.timeIntervalSince(began), holds: frames.holds)
                    ZStack {
                        frames.pictures[now.index].resizable().scaledToFit()
                        if now.blend > 0, frames.pictures.indices.contains(now.index + 1) {
                            frames.pictures[now.index + 1].resizable().scaledToFit().opacity(now.blend)
                        }
                    }
                }
            }
        }
        .mask {
            LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.1),
                                   .init(color: .black, location: 0.9), .init(color: .clear, location: 1)],
                           startPoint: .top, endPoint: .bottom)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityAddTraits(.isImage)
        .accessibilityLabel(reduceMotion
                            ? "A golden retriever with a little snow on her nose"
                            : "A golden retriever running up through the snow")
        .onAppear { began = Date() }
        .onChange(of: reduceMotion) { _, _ in began = Date() }
    }
}
