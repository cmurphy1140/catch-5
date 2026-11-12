@testable import CatchFiveUI
import Testing

@Test func approvedDogRunKeepsTheSeatedOpeningAndSnowyNoseHolds() {
    let running = [0.16, 0.20, 0.12, 0.20, 0.12, 0.16, 0.20, 0.90]
    #expect(GuestDogRunMotion.holds(runningFrames: 8, intro: false) == running)
    let full = GuestDogRunMotion.holds(runningFrames: 8, intro: true)
    #expect(full == [0.56] + running)
    #expect(abs(full.reduce(0, +) - 2.62) < 0.0001)
    #expect(full.last == 0.90)
}

@Test func approvedDogRunMovesAtItsRecordedBoundariesAndKeepsTheLastStill() {
    let holds = GuestDogRunMotion.holds(runningFrames: 8, intro: true)
    #expect(GuestDogRunMotion.frame(at: -2, holds: holds).index == 0)
    #expect(GuestDogRunMotion.frame(at: 0.55, holds: holds).index == 0)
    #expect(GuestDogRunMotion.frame(at: 0.57, holds: holds).index == 1)
    #expect(GuestDogRunMotion.frame(at: 0.73, holds: holds).index == 2)
    #expect(GuestDogRunMotion.frame(at: 1.73, holds: holds).index == 8)
    let held = GuestDogRunMotion.frame(at: 20, holds: holds)
    #expect(held.index == 8 && held.blend == 0)
    #expect(GuestDogRunMotion.frame(at: 2, holds: []).index == 0)
}

@Test func partialDogArtUsesAvailableFramesWithoutInventingMorePictures() {
    let holds = GuestDogRunMotion.holds(runningFrames: 3, intro: false)
    #expect(holds.count == 3)
    #expect(abs(holds.reduce(0, +) - GuestDogRunMotion.duration(frames: 3)) < 0.0001)
    #expect(GuestDogRunMotion.frame(at: 20, holds: holds).index == 2)
    #expect(GuestDogRunMotion.holds(runningFrames: 0, intro: false).isEmpty)
}
