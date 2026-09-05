import CatchFive
import CatchFiveUI
import Foundation
import Testing

@MainActor @Test func humanActionAdvancesComputersAndStopsForHuman() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.send(.bid(9))
    #expect(model.match.hand.nextSeat == 1)
    for _ in 0..<3 { model.stepComputer() }
    #expect(model.isHumanTurn)
    #expect(model.match.hand.phase == .choosingTrump)
    model.stepComputer()
    #expect(model.match.hand.phase == .choosingTrump)
    model.send(.chooseTrump(.hearts))
    #expect(model.match.hand.phase == .playing)
    model.send(.play(try #require(model.humanCards.first)))
    #expect(model.match.hand.currentTrick.count == 1)
}

@MainActor @Test func acceptedHumanMoveSavesAndInvalidMoveShowsError() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let model = GameModel(match: try Match(deck: deck, dealer: 3), saveURL: url)
    model.send(.bid(1))
    #expect(model.errorMessage != nil)
    #expect(model.match.hand.nextSeat == 0)
    model.send(.bid(2))
    #expect(model.errorMessage == nil)
    let restored = try MatchSave.read(from: url)
    #expect(restored.hand.auction.highestBid == 2)
    #expect(restored.hand.nextSeat == 1)
}

@MainActor @Test func modelDescribesAuctionCallsAndContract() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    #expect(model.latestCall(for: 0) == nil)
    #expect(model.contract == nil)
    model.send(.bid(nil))
    #expect(model.latestCall(for: 0) == "Pass")
    for _ in 0..<3 { model.stepComputer() }
    #expect(model.match.hand.phase == .choosingTrump)
    let bidder = try #require(model.match.hand.auction.winner)
    let bid = try #require(model.match.hand.auction.highestBid)
    #expect(model.latestCall(for: bidder) == "Bid \(bid)")
    #expect(model.contract == "\(model.seatNames[bidder]) bid \(bid)")
}

@MainActor @Test func hintMatchesTheComputerStrategyAndClearsAfterActing() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    #expect(model.hint == nil)
    model.showHint()
    let hint = try #require(model.hint)
    #expect(hint.action == ComputerPlayer.decide(try PlayerView(match: model.match, seat: 0)))
    #expect(!hint.reason.isEmpty)
    model.send(hint.action)
    #expect(model.hint == nil)
    model.showHint()
    #expect(model.hint == nil)   // not the human's turn
}

@MainActor @Test func explanationsNameTheSeatAndCompareTheHumanToTheStrategy() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.send(.bid(9))   // nobody can outbid nine, so the human names trump and leads
    for _ in 0..<3 { model.stepComputer() }
    model.send(.chooseTrump(.clubs))
    // Play the card the strategy would not choose, if there is one, then let the computers follow.
    let advice = try #require(ComputerPlayer.advise(PlayerView(match: model.match, seat: 0)))
    let other = model.humanCards.first { model.allows(.play($0)) && .play($0) != advice.action }
    model.send(.play(other ?? model.humanCards[0]))
    for _ in 0..<3 { model.stepComputer() }
    let trick = try #require(model.match.hand.completedTricks.last)
    let west = try #require(model.explanation(for: trick.plays[1], inLastTrick: true))
    #expect(west.hasPrefix("West played the \(trick.plays[1].card.name)"))
    let you = try #require(model.explanation(for: trick.plays[0], inLastTrick: true))
    #expect(you.hasPrefix("You played the"))
    if other != nil { #expect(you.contains("strategy would have")) }
    model.explain(trick.plays[1], inLastTrick: true)
    #expect(model.explanation == west)
    model.explain(trick.plays[1], inLastTrick: true)
    #expect(model.explanation == nil)   // second tap dismisses
}

@MainActor @Test func humanCardsSortTrumpFirstThenBySuitAndRank() throws {
    var deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    deck.swapAt(0, 30)   // seat 0 holds a mixed hand
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    model.send(.chooseTrump(.clubs))
    let cards = model.humanCards
    #expect(Set(cards) == Set(model.match.hand.hands[0]))
    let trumps = cards.prefix { $0.suit == .clubs }
    #expect(!trumps.isEmpty && !cards.dropFirst(trumps.count).contains { $0.suit == .clubs })
    #expect(trumps.map(\.rank.rawValue) == trumps.map(\.rank.rawValue).sorted(by: >))
}

@Test func delayDependsOnPlaySpeedAndLeadPosition() {
    var settings = Settings()
    #expect(settings.delay(leadingTrick: true) > settings.delay(leadingTrick: false))
    settings.playSpeed = .quick
    let quick = settings.delay(leadingTrick: true)
    settings.playSpeed = .relaxed
    #expect(settings.delay(leadingTrick: true) > quick)
}

@Test func settingsRoundTripThroughDiskAndTolerateMissingKeys() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var settings = Settings()
    settings.playSpeed = .quick
    settings.seatNames[1] = "Mum"
    settings.haptics = false
    try SettingsStore.write(settings, to: url)
    #expect(try SettingsStore.read(from: url) == settings)
    try Data("{\"playSpeed\":\"relaxed\"}".utf8).write(to: url)
    let partial = try SettingsStore.read(from: url)
    #expect(partial.playSpeed == .relaxed && partial.seatNames == Settings.defaultSeatNames && partial.haptics)
}

@MainActor @Test func seatNamesFlowIntoContractAndExplanations() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.settings.seatNames = ["Connor", "Mum", "Dad", "Sis"]
    model.send(.bid(nil))
    for _ in 0..<3 { model.stepComputer() }
    let bidder = try #require(model.match.hand.auction.winner)
    #expect(model.contract?.hasPrefix(["Connor", "Mum", "Dad", "Sis"][bidder]) == true)
}

@MainActor @Test func illegalPlayExplainsFollowSuitInPlainWords() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 0))   // West leads after the auction
    for _ in 0..<3 { model.stepComputer() }
    model.send(.bid(9))
    model.send(.chooseTrump(.hearts))
    #expect(model.match.hand.nextSeat == 0)
    model.send(.play(Card(.clubs, .two)))   // not held
    #expect(model.errorMessage?.contains("not in your hand") == true)
    #expect(GameModel.message(for: HandError.mustFollowSuit).contains("follow suit"))
    #expect(GameModel.message(for: RuleError.invalidBid).contains("bid"))
}

@MainActor @Test func trumpChoiceReportsDiscards() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    let nonTrumps = model.humanCards.filter { $0.suit != .hearts }.count
    model.send(.chooseTrump(.hearts))
    #expect(model.notice == (nonTrumps == 0 ? "You kept all six cards." : "You discarded \(nonTrumps) and drew \(nonTrumps)."))
    model.send(.play(model.humanCards[0]))
    #expect(model.notice == nil)
}
