import SwiftUI

/// How the guest's dog moves (D178), as plain numbers so it can be checked without a screen: she trots in on diagonal
/// pairs of legs, slows, lowers herself, and then lies there breathing, with a wag of the tail now and then.
enum GuestDogMotion {
    /// One moment of her: where she is and how each piece is turned.
    struct Pose: Equatable {
        /// 1 at the edge she comes in from, 0 at her place.
        var travel = 0.0
        /// Degrees for the near front, far front, near back and far back legs.
        var legs = [0.0, 0.0, 0.0, 0.0]
        /// How far the standing body is lifted by her step, as a fraction of her height.
        var bob = 0.0
        var head = 0.0
        var tail = 0.0
        /// 0 standing, 1 lying; between the two the standing figure sinks and the lying one comes up.
        var lying = 0.0
        /// The lying figure's height, a breath in and out about 1.
        var breath = 1.0
    }

    static let walk = 2.6, settle = 0.7
    static let stride = 24.0, stepsPerSecond = 2.1

    /// The resting pose, for Reduce Motion and for the end of every opening.
    static let rest = Pose(lying: 1)

    static func pose(at time: Double) -> Pose {
        guard time > 0 else { return Pose(travel: 1) }
        var pose = Pose()
        if time < walk + settle {
            // She covers the ground fast and eases to a stop; her legs swing less as she slows.
            let part = min(1, time / walk), eased = 1 - pow(1 - part, 2.2)
            let pace = time < walk ? max(0.25, 1 - eased * 0.75) : max(0, 0.25 * (1 - (time - walk) / settle * 2.5))
            let phase = time * stepsPerSecond * 2 * .pi
            let swing = stride * pace * sin(phase)
            pose.travel = 1 - eased
            pose.legs = [swing, -swing, -swing, swing]
            pose.bob = 0.018 * pace * abs(sin(phase))
            pose.head = 3 * pace * sin(phase * 2)
            pose.tail = 14 * sin(time * 9)
            if time > walk {
                let down = (time - walk) / settle
                pose.lying = down * down * (3 - 2 * down)
            }
            return pose
        }
        let lain = time - walk - settle
        pose.lying = 1
        pose.breath = 1 + 0.014 * sin(lain * 2 * .pi / 3.4)
        // A happy wag as she lands, then a shorter one every few seconds.
        let since = lain.truncatingRemainder(dividingBy: 6.5)
        let wag = lain < 2.2 ? 1 - lain / 2.2 : (since < 1.4 ? sin(since / 1.4 * .pi) * 0.7 : 0)
        pose.tail = 20 * wag * sin(lain * 13)
        return pose
    }
}

/// The guest's dog as a paper puppet (D178): separate cut-out pieces, each drawn the size of one shared frame so they
/// line up, turned about their joints. Standing and lying are two sets of pieces; one sinks as the other rises.
struct GuestDogFigure: View {
    struct Parts {
        let body: Image, head: Image, tail: Image
        /// Near front, far front, near back, far back.
        let legs: [Image]
        let lying: Image, lyingTail: Image
    }

    /// Where each piece turns, as a point in its frame, and the frames' shapes (height over width).
    struct Joints {
        var legs: [UnitPoint] = [.init(x: 0.36, y: 0.56), .init(x: 0.28, y: 0.56), .init(x: 0.70, y: 0.56), .init(x: 0.62, y: 0.56)]
        var neck = UnitPoint(x: 0.30, y: 0.38)
        var tail = UnitPoint(x: 0.74, y: 0.38)
        var lyingTail = UnitPoint(x: 0.78, y: 0.70)
        var standing = 0.75, lying = 0.5
    }

    let parts: Parts
    var joints = Joints()
    let pose: GuestDogMotion.Pose
    let width: Double

    var body: some View {
        let height = width * joints.standing, low = width * joints.lying
        ZStack(alignment: .bottom) {
            if pose.lying < 1 {
                ZStack {
                    piece(parts.legs[1], height).rotationEffect(.degrees(pose.legs[1]), anchor: joints.legs[1])
                    piece(parts.legs[3], height).rotationEffect(.degrees(pose.legs[3]), anchor: joints.legs[3])
                    Group {
                        piece(parts.tail, height).rotationEffect(.degrees(pose.tail), anchor: joints.tail)
                        piece(parts.body, height)
                    }
                    .offset(y: -pose.bob * height)
                    piece(parts.legs[0], height).rotationEffect(.degrees(pose.legs[0]), anchor: joints.legs[0])
                    piece(parts.legs[2], height).rotationEffect(.degrees(pose.legs[2]), anchor: joints.legs[2])
                    piece(parts.head, height).rotationEffect(.degrees(pose.head), anchor: joints.neck).offset(y: -pose.bob * height)
                }
                // Lowering herself: the standing figure sinks towards the ground and thins out of sight.
                .scaleEffect(x: 1, y: 1 - 0.3 * pose.lying, anchor: .bottom)
                .opacity(1 - pose.lying)
            }
            if pose.lying > 0 {
                ZStack {
                    piece(parts.lyingTail, low).rotationEffect(.degrees(pose.tail), anchor: joints.lyingTail)
                    piece(parts.lying, low)
                }
                .scaleEffect(x: 1, y: pose.breath * (0.9 + 0.1 * pose.lying), anchor: .bottom)
                .opacity(pose.lying)
            }
        }
        .frame(width: width, height: height, alignment: .bottom)
        .accessibilityHidden(true)
    }

    private func piece(_ image: Image, _ height: Double) -> some View {
        image.resizable().frame(width: width, height: height)
    }
}

/// The dog on the guest's page: she comes in from `distance` away once, then stays. With Reduce Motion she is simply
/// lying there.
struct GuestDog: View {
    let parts: GuestDogFigure.Parts
    var joints = GuestDogFigure.Joints()
    let width: Double
    /// How far off she starts, towards the side she faces away from.
    let distance: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var start = Date()

    var body: some View {
        if reduceMotion {
            GuestDogFigure(parts: parts, joints: joints, pose: GuestDogMotion.rest, width: width)
        } else {
            TimelineView(.animation) { timeline in
                let pose = GuestDogMotion.pose(at: timeline.date.timeIntervalSince(start))
                GuestDogFigure(parts: parts, joints: joints, pose: pose, width: width)
                    .offset(x: pose.travel * distance)
            }
        }
    }
}
