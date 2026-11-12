@testable import CatchFiveUI
import Testing

@Test func theDogWalksInThenLiesDownAndStaysPut() {
    #expect(GuestDogMotion.pose(at: 0).travel == 1)
    let early = GuestDogMotion.pose(at: 0.5), late = GuestDogMotion.pose(at: 2.0)
    #expect(early.travel > late.travel && late.travel > 0 && early.lying == 0)
    let arrived = GuestDogMotion.pose(at: GuestDogMotion.walk)
    #expect(arrived.travel == 0 && arrived.lying == 0)
    let half = GuestDogMotion.pose(at: GuestDogMotion.walk + GuestDogMotion.settle / 2)
    #expect(half.lying > 0 && half.lying < 1 && half.travel == 0)
    for time in [GuestDogMotion.walk + GuestDogMotion.settle, 10, 500] {
        let pose = GuestDogMotion.pose(at: time)
        #expect(pose.lying == 1 && pose.travel == 0 && pose.legs == [0, 0, 0, 0])
        #expect(abs(pose.breath - 1) <= 0.015 && abs(pose.tail) <= 20)
    }
}

@Test func theDogTrotsOnDiagonalPairsAndHerStepsShortenAsSheSlows() {
    let pose = GuestDogMotion.pose(at: 0.3)
    #expect(pose.legs[0] == -pose.legs[1] && pose.legs[0] == pose.legs[3] && pose.legs[1] == pose.legs[2])
    let widest = { (range: ClosedRange<Double>) in
        stride(from: range.lowerBound, through: range.upperBound, by: 0.01).map { abs(GuestDogMotion.pose(at: $0).legs[0]) }.max() ?? 0
    }
    #expect(widest(0.1...0.6) > widest(2.0...2.5))
    #expect(widest(0.1...0.6) <= GuestDogMotion.stride)
}
