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

@MainActor @Test func easySettingDrivesComputersButNotHintsAndLabelsExplanations() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.settings.difficulty = .easy
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    model.send(.chooseTrump(.clubs))
    model.showHint()
    let hint = try #require(model.hint)
    #expect(hint.action == ComputerPlayer.decide(try PlayerView(match: model.match, seat: 0)))   // Standard, not Easy
    model.send(hint.action)
    let before = model.match
    model.stepComputer()
    let played = try #require(model.match.hand.currentTrick.last)
    #expect(.play(played.card) == EasyPlayer.decide(try PlayerView(match: before, seat: 1)))
    let text = try #require(model.explanation(for: played, inLastTrick: false))
    #expect(text.hasPrefix("West (easy) played the \(played.card.name)"))
    #expect(text.contains("Standard"))
}

@Test func rulesSheetContainsEveryHouseRuleParagraph() throws {
    // The rules document is the source of truth; the sheet must quote every rule paragraph verbatim.
    let docs = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("docs/catch-five-rules.md")
    let text = try String(contentsOf: docs, encoding: .utf8)
    let rules = text.components(separatedBy: "## Pending")[0]
    let paragraphs = rules.split(separator: "\n").map(String.init).filter { !$0.isEmpty && !$0.hasPrefix("#") }
    #expect(paragraphs.count >= 8)
    for paragraph in paragraphs { #expect(RulesText.allText.contains(paragraph), "missing: \(paragraph.prefix(40))") }
    #expect(RulesText.sections.flatMap(\.paragraphs).count == paragraphs.count)
}

@MainActor @Test func firstLaunchShowsRulesOnce() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let model = GameModel(match: try Match(deck: deck, dealer: 3), settingsURL: url)
    #expect(model.needsRulesIntroduction)
    model.markRulesSeen()
    #expect(!model.needsRulesIntroduction)
    let reloaded = GameModel(match: try Match(deck: deck, dealer: 3), settings: try SettingsStore.read(from: url))
    #expect(!reloaded.needsRulesIntroduction)
}

@MainActor @Test func undoneMatchSavesAndReloads() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let model = GameModel(match: try Match(deck: deck, dealer: 3), saveURL: url)
    #expect(!model.canUndo)
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    #expect(model.match.hand.phase == .choosingTrump && model.canUndo)
    let revision = model.revision
    model.undo()
    #expect(model.match.hand.phase == .bidding && model.match.hand.nextSeat == 0 && model.match.actionCount == 0)
    #expect(model.revision == revision + 1)
    #expect(try MatchSave.read(from: url).actionCount == 0)
    #expect(!model.canUndo)
}

@MainActor private func finishMatch(_ model: GameModel) throws {
    for _ in 0..<20000 {
        if model.match.winner != nil { return }
        if model.match.hand.phase == .finished { model.nextHand(); continue }
        if model.isHumanTurn {
            model.showHint()
            model.send(try #require(model.hint).action)
        } else {
            model.stepComputer()
        }
    }
}

@MainActor @Test func finishedMatchIsRecordedExactlyOnce() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3), historyURL: url)
    let stamp = Date(timeIntervalSince1970: 1_800_000_000)
    model.now = { stamp }
    try finishMatch(model)
    #expect(model.records.count == 1)
    let record = try #require(model.records.first)
    #expect(record.date == stamp && record.scores == model.match.scores && record.hands == model.match.history.count)
    #expect(record.humanPlays == record.humanPlaysAgreed && record.humanPlays == record.hands * 6)
    #expect(model.handReview()?.tricks.count == 6)
    model.showHint()   // a no-op after the match; must not record again
    #expect(try MatchHistoryStore.read(from: url) == model.records)
    let restored = GameModel(match: model.match, records: try MatchHistoryStore.read(from: url), historyURL: url)
    restored.newGame()
    #expect(restored.records.count == 1)
    try finishMatch(restored)
    #expect(restored.records.count == 2)
}

@Test func statisticsAggregateAcrossRecords() {
    let won = MatchRecord(date: .init(), scores: [26, 10], winner: 0, hands: 6, difficulty: .standard, humanBids: 2, humanBidsMade: 2, humanPlays: 36, humanPlaysAgreed: 27)
    let lost = MatchRecord(date: .init(), scores: [12, 25], winner: 1, hands: 5, difficulty: .easy, humanBids: 2, humanBidsMade: 1, humanPlays: 30, humanPlaysAgreed: 15)
    let stats = Statistics([won, lost])
    #expect(stats.matches == 2 && stats.wins == 1)
    #expect(stats.averageMargin == 1.5)
    #expect(stats.contractRate == 0.75)
    #expect(stats.agreementRate.map { abs($0 - 42.0 / 66.0) < 0.0001 } == true)
    #expect(Statistics([]).contractRate == nil && Statistics([]).averageMargin == 0)
}

@MainActor @Test func corruptHistoryDoesNotBlockPlay() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("not json".utf8).write(to: url)
    #expect(throws: (any Error).self) { try MatchHistoryStore.read(from: url) }
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3), records: (try? MatchHistoryStore.read(from: url)) ?? [], historyURL: url)
    #expect(model.records.isEmpty)
    model.showHint()
    model.send(try #require(model.hint).action)
    #expect(model.errorMessage == nil)
}
