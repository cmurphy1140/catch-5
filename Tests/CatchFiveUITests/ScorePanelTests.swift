import CatchFive
@testable import CatchFiveUI
import Foundation
import Testing

@MainActor @Test func eachTeamsPanelShowsItsTotalDotsAndHands() throws {
    // N62: a 5 bid by seat 0, played out; each panel carries its own total, dots to 25 and the hand so far.
    var match = try Match(deck: RootView.nineAndOutDeck(), dealer: 3)
    try match.bid(seat: 0, amount: 5)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .hearts)
    while match.hand.phase != .finished {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    let names = ["Cheryl", "Marcus", "Meg", "Monica"]
    for team in 0...1 {
        let panel = ScorePanel.content(team: team, history: match.history, seatNames: names)
        #expect(panel.total == match.scores[team])
        #expect(panel.dots == min(25, max(0, match.scores[team])))
        #expect(panel.hands.count == 1)
        #expect(panel.hands[0].number == 1)
        #expect(panel.hands[0].line == "Cheryl bid 5, \(match.history[0].contractMade ? "made" : "set")")
        #expect(panel.hands[0].change == match.scores[team])
        #expect(panel.hands[0].total == match.scores[team])
        #expect(panel.hands[0].ourBid == (team == 0))
    }
    #expect(ScorePanel.content(team: 1, history: [], seatNames: names) == ScorePanel.Content(total: 0, dots: 0, hands: []))
    #expect(ScorePanel.dots(-3) == 0 && ScorePanel.dots(31) == 25 && ScorePanel.dots(12) == 12)
}

@MainActor @Test func theTallyDemoShowsOnceAndTheFlagPersists() throws {
    // N61: the first time trump is named on this install the table shows the two taps, then never again.
    #expect(Settings().hasSeenTallyDemo == false)
    #expect(try JSONDecoder().decode(Settings.self, from: Data("{}".utf8)).hasSeenTallyDemo == false)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3), settingsURL: url)
    model.beginTallyDemoIfDue()
    #expect(model.tallyDemo == nil)
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    model.send(.chooseTrump(.hearts))
    #expect(model.match.hand.trump == .hearts)
    model.beginTallyDemoIfDue()
    #expect(model.tallyDemo == .trump)
    #expect(model.tallyDemo?.caption == "Count trump as it falls")
    model.advanceTallyDemo()
    #expect(model.tallyDemo == .face(seat: model.seat(at: 1)))
    #expect(model.tallyDemo?.caption == "Mark who's out of trump")
    model.advanceTallyDemo()
    #expect(model.tallyDemo == nil)
    model.beginTallyDemoIfDue()
    #expect(model.tallyDemo == nil)
    #expect(try SettingsStore.read(from: url).hasSeenTallyDemo)
    let reloaded = GameModel(match: model.match, settings: try SettingsStore.read(from: url))
    reloaded.beginTallyDemoIfDue()
    #expect(reloaded.tallyDemo == nil)
}

@MainActor @Test func theTallyDemoLeavesTheTallyAndBadgesAlone() throws {
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    model.send(.chooseTrump(.spades))
    model.beginTallyDemoIfDue()
    while model.tallyDemo != nil {
        #expect(model.trumpTally == 0 && model.outOfTrump.isEmpty)
        model.advanceTallyDemo()
    }
    #expect(model.trumpTally == 0 && model.outOfTrump.isEmpty)
}
