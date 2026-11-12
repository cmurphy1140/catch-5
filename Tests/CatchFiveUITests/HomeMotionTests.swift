@testable import CatchFiveUI
import Testing

@Test func theGreetingFollowsTheHourAndNamesTheGuest() {
    #expect(HomeMotion.greeting(hour: 8, guest: "Emma") == "Morning at the Emma table")
    #expect(HomeMotion.greeting(hour: 12, guest: "Emma") == "Afternoon at the Emma table")
    #expect(HomeMotion.greeting(hour: 21, guest: "Emma") == "Evening at the Emma table")
    #expect(HomeMotion.greeting(hour: 23, guest: nil) == "Late night at the table")
    #expect(HomeMotion.greeting(hour: 4, guest: nil) == "Late night at the table")
}

@Test func theFiveLeansWithThePhoneButOnlySoFar() {
    let level = HomeMotion.lean(roll: 0, pitch: 45)
    #expect(level.x == 0 && level.y == 0 && level.glareX == 0.5 && level.glareY == 0.5)
    let far = HomeMotion.lean(roll: 90, pitch: -90)
    #expect(far.y == 5 && far.x == 5 && far.glareX == 0.9 && abs(far.glareY - 0.1) < 0.0001)
    #expect(HomeMotion.seats.count == 5 && HomeMotion.seats.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
}
