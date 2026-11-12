@testable import CatchFiveUI
import Foundation
import Testing

@Test func passAndPlayNamesAreTrimmedAndABlankOneTakesItsFallback() {
    let fallback = ["Cheryl", "Marcus", "Meg", "Monica"]
    #expect(Settings.passAndPlayNames(typed: [" Dad ", "", "Emma", "   "], fallback: fallback) == ["Dad", "Marcus", "Emma", "Monica"])
    #expect(Settings.passAndPlayNames(typed: [], fallback: fallback) == fallback)
    #expect(Settings.passAndPlayNames(typed: ["A", "B", "C", "D", "E"], fallback: []) == ["A", "B", "C", "D"])
}

@Test func passAndPlayHasItsOwnFourAndSoloKeepsItsSeatNames() {
    var settings = Settings()
    settings.setPlayerName("Emma")
    #expect(settings.names(passAndPlay: false) == ["Emma", "Marcus", "Meg", "Monica"])
    // Before the sheet has been used, pass and play reads the seat names as it always did.
    #expect(settings.names(passAndPlay: true) == ["Cheryl", "Marcus", "Meg", "Monica"])
    settings.passAndPlayNames = ["Dad", "Mum", "Emma", "Sam"]
    #expect(settings.names(passAndPlay: true) == ["Dad", "Mum", "Emma", "Sam"])
    #expect(settings.names(passAndPlay: false) == ["Emma", "Marcus", "Meg", "Monica"])
    settings.renameSeat(1, to: " Nan ", passAndPlay: true)
    #expect(settings.passAndPlayNames == ["Dad", "Nan", "Emma", "Sam"] && settings.seatNames[1] == "Marcus")
    settings.renameSeat(1, to: "Otis")
    #expect(settings.seatNames[1] == "Otis" && settings.passAndPlayNames?[1] == "Nan")
}

@Test func passAndPlayNamesSurviveASaveAndAnOlderSaveLoadsWithoutThem() throws {
    var settings = Settings()
    settings.passAndPlayNames = ["Dad", "Mum", "Emma", "Sam"]
    let saved = try JSONEncoder().encode(settings)
    #expect(try JSONDecoder().decode(Settings.self, from: saved).passAndPlayNames == ["Dad", "Mum", "Emma", "Sam"])
    var object = try #require(JSONSerialization.jsonObject(with: saved) as? [String: Any])
    object["passAndPlayNames"] = nil
    let older = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(older.passAndPlayNames == nil && older.names(passAndPlay: true).count == 4)
    object["passAndPlayNames"] = ["only", "three", "names"]
    let damaged = try JSONDecoder().decode(Settings.self, from: JSONSerialization.data(withJSONObject: object))
    #expect(damaged.passAndPlayNames == nil)
}
