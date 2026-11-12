@testable import CatchFiveUI
import Testing

@Test func guestLooksAreCountedUntilTheFirstMissingPicture() {
    let carried: Set<String> = ["GuestLook1", "GuestLook2", "GuestLook4"]
    #expect(GuestLook.names { carried.contains($0) } == ["GuestLook1", "GuestLook2"])
    #expect(GuestLook.names { _ in false }.isEmpty)
    #expect(GuestLook.names(limit: 3) { _ in true } == ["GuestLook1", "GuestLook2", "GuestLook3"])
}

@Test func aSavedLookIsWornOnlyWhileTheBuildCarriesIt() {
    #expect(GuestLook.worn(saved: "GuestLook2", among: ["GuestLook1", "GuestLook2"]) == "GuestLook2")
    #expect(GuestLook.worn(saved: "GuestLook9", among: ["GuestLook1"]) == nil)
    #expect(GuestLook.worn(saved: nil, among: ["GuestLook1"]) == nil)
}
