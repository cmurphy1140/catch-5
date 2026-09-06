import CatchFive
@testable import CatchFiveUI
import Foundation
import SwiftUI
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
    #expect(west.hasPrefix("\(Settings.defaultSeatNames[1]) played the \(trick.plays[1].card.name)"))
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
    #expect(text.hasPrefix("\(Settings.defaultSeatNames[1]) (easy) played the \(played.card.name)"))
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
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3), records: MatchHistoryStore.readSettingAsideCorruption(at: url), historyURL: url)
    #expect(model.records.isEmpty)
    model.showHint()
    model.send(try #require(model.hint).action)
    #expect(model.errorMessage == nil)
}

@MainActor @Test func spokenDescriptionOfPlayNamesSeatAndCard() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.settings.seatNames[1] = "Mum"
    #expect(model.spokenDescription(of: Play(seat: 1, card: Card(.hearts, .ten))) == "Mum played the ten of hearts")
    #expect(model.spokenDescription(of: Play(seat: 0, card: Card(.spades, .ace))) == "You played the ace of spades")
    #expect(model.spokenDescription(of: Play(seat: 1, card: Card(.hearts, .ten)), winner: 1) == "Mum played the ten of hearts and took the trick")
}

@MainActor @Test func accessibilityValueReflectsLegality() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 0))   // West leads after the auction
    for _ in 0..<3 { model.stepComputer() }
    model.send(.bid(9))
    #expect(model.accessibilityValue(for: model.humanCards[0]) == "waiting for the auction to finish")
    model.send(.chooseTrump(.clubs))
    #expect(model.isHumanTurn)
    let legal = Set(model.match.hand.legalMoves(seat: 0))
    for card in model.humanCards {
        #expect(model.accessibilityValue(for: card) == (legal.contains(card) ? "playable" : "not legal now"))
    }
    model.send(.play(try #require(legal.first)))
    #expect(model.accessibilityValue(for: model.humanCards[0]) == "waiting for your turn")
}

@Test func matchRecordDecodesOlderFilesAndRejectsBadScores() throws {
    let older = Data("[{\"date\":\"2026-09-04T20:00:00Z\",\"scores\":[26,10],\"winner\":0,\"hands\":6}]".utf8)
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try older.write(to: url)
    let records = try MatchHistoryStore.read(from: url)
    #expect(records.count == 1)
    #expect(records[0].scores == [26, 10] && records[0].humanBids == 0 && records[0].difficulty == .standard)
    try Data("[{\"date\":\"2026-09-04T20:00:00Z\",\"scores\":[26],\"winner\":0,\"hands\":6}]".utf8).write(to: url)
    #expect(throws: (any Error).self) { try MatchHistoryStore.read(from: url) }
}

@MainActor @Test func corruptHistoryIsSetAsideByLoadDefault() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("not json".utf8).write(to: directory.appendingPathComponent("history.json"))
    let model = GameModel.loadDefault(in: directory)
    #expect(model.records.isEmpty)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("history-corrupt.json").path))
    #expect(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("history.json").path))
    // The drawn dealer may put a computer first; play stays usable either way.
    while !model.isHumanTurn { model.stepComputer() }
    model.showHint()
    model.send(try #require(model.hint).action)
    #expect(model.errorMessage == nil)
}

@MainActor @Test func reviewRowsShareExplanationWordingAndLabelEasySeats() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    model.settings.difficulty = .easy
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    model.send(.chooseTrump(.clubs))
    while model.match.hand.phase == .playing {
        if model.isHumanTurn { model.showHint(); model.send(try #require(model.hint).action) } else { model.stepComputer() }
    }
    let review = try #require(model.handReview())
    let west = try #require(review.tricks[0].plays.first { $0.play.seat == 1 })
    let text = model.describe(west)
    #expect(text.hasPrefix("\(Settings.defaultSeatNames[1]) (easy) played the \(west.play.card.name)"))
    #expect(text == model.explanation(for: west.play, inLastTrick: false, trickIndex: 0))
    #expect(!text.contains("::") && !text.contains("Play the"))
    #expect(model.finalPerformance == nil)
}

@Test func fannedHandCardsKeepAThumbSizedStrip() {
    // Six overlapped cards must fit the narrowest supported phone and each expose 44pt (docs/redesign-plan.md).
    for width in [Theme.Card.handWidth, Theme.Card.handWidthWide] {
        #expect(Theme.Card.touchStrip(width: width) >= Theme.Card.minimumTouchStrip)
        #expect(width + 5 * Theme.Card.touchStrip(width: width) <= 375 - 32)
    }
    #expect(abs(Theme.Card.radius(width: 60) - 3.6) < 0.0001)
}

@MainActor @Test func lastHumanActionDescribesThePlayAndClearsOnUndo() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    #expect(model.lastHumanAction == nil)
    model.send(.bid(9))
    #expect(model.lastHumanAction == .bid(9))
    #expect(model.describe(.bid(9)) == "Bid 9" && model.describe(.bid(nil)) == "Passed")
    for _ in 0..<3 { model.stepComputer() }
    #expect(model.lastHumanAction == .bid(9))   // computer replies do not overwrite it
    model.send(.chooseTrump(.hearts))
    #expect(model.describe(try #require(model.lastHumanAction)) == "♥ named trump")
    let card = model.humanCards[0]
    model.send(.play(card))
    #expect(model.describe(.play(card)) == "\(card.label)\(card.suit.glyph) played")
    model.undo()
    #expect(model.lastHumanAction == nil)
    #expect(!model.humanCards.contains(Card(.clubs, .two)))
    model.send(.play(Card(.clubs, .two)))   // not held, so rejected: a failed send leaves it nil
    #expect(model.errorMessage != nil && model.lastHumanAction == nil)
}

@Test func schedulerHoldsAFinishedTrickOnceThenTreatsTheNextPlayAsALead() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var match = try Match(deck: deck, dealer: 3)
    // During the auction there is nothing to hold and nothing to lead.
    #expect(TableScheduler.plan(hand: match.hand, collapsedTricks: 0) == (false, true, false))
    try match.bid(seat: 0, amount: 9)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    #expect(TableScheduler.plan(hand: match.hand, collapsedTricks: 0) == (false, true, true))   // first lead waits for the deal
    try match.play(seat: 0, card: try #require(match.hand.legalMoves(seat: 0).first))
    #expect(TableScheduler.plan(hand: match.hand, collapsedTricks: 0) == (false, false, false))  // a follow
    for _ in 0..<3 {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    #expect(match.hand.completedTricks.count == 1)
    #expect(TableScheduler.plan(hand: match.hand, collapsedTricks: 0) == (true, false, false))   // hold, then a lead follows the hold
    #expect(TableScheduler.plan(hand: match.hand, collapsedTricks: 1) == (false, true, false))   // already collapsed: plain lead
}

@MainActor @Test func noticeSurvivesComputerRepliesUntilTheHumanActs() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 0))   // West bids first
    for _ in 0..<3 { model.stepComputer() }
    model.send(.bid(9))
    model.send(.chooseTrump(.hearts))
    let notice = try #require(model.notice)
    #expect(notice.hasPrefix("You discarded") || notice == "You kept all six cards.")
    #expect(model.describe(.nineAndOut) == "Bid 9 and out")
    // Play a card: the notice belongs to the previous action and clears.
    model.send(.play(try #require(model.humanCards.first)))
    #expect(model.notice == nil)
}

@Test func castHasThreeDistinctNamesAndPortraits() {
    #expect(Cast.opponents.count == 3)
    #expect(Set(Cast.opponents.map(\.name)).count == 3)
    #expect(Set(Cast.opponents.map(\.portrait)).count == 3)
    #expect(Cast.opponents.map(\.name) == ["Hazel", "Otto", "Rue"])
    #expect(Cast.playerChoices.count == 4)
    #expect(Set(Cast.playerChoices).count == 4)
    #expect(Cast.defaultPlayerPortrait == Cast.playerChoices[0])
    #expect(Cast.seatWords == ["You", "West", "Partner", "East"])
}

@Test func settingsRoundTripKeepsPlayerNameAndPortrait() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    var settings = Settings()
    #expect(!settings.hasSignedIn)
    settings.playerName = "Connor"
    settings.playerPortrait = Cast.playerChoices[2]
    try SettingsStore.write(settings, to: url)
    let read = try SettingsStore.read(from: url)
    #expect(read == settings)
    #expect(read.hasSignedIn && read.playerName == "Connor" && read.playerPortrait == Cast.playerChoices[2])
}

@Test func settingsWithoutPlayerFieldsLoadsSignedOut() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("{\"playSpeed\":\"relaxed\"}".utf8).write(to: url)
    let settings = try SettingsStore.read(from: url)
    #expect(settings.playerName == nil && !settings.hasSignedIn)
    #expect(settings.playerPortrait == Cast.defaultPlayerPortrait)
    #expect(settings.seatNames == ["You", "Hazel", "Otto", "Rue"])
}

@Test func oldSettingsFileMigratesDefaultSeatNamesToCast() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    try Data("{\"seatNames\":[\"You\",\"West\",\"Mum\",\"East\"]}".utf8).write(to: url)
    let settings = try SettingsStore.read(from: url)
    #expect(settings.seatNames == ["You", "Hazel", "Mum", "Rue"])
}

@MainActor @Test func matchInProgressIsFalseForFreshAndFinishedMatches() throws {
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    #expect(!model.matchInProgress)
    model.send(.bid(nil))
    #expect(model.matchInProgress)
    try finishMatch(model)
    #expect(model.match.winner != nil)
    #expect(!model.matchInProgress)
    model.newGame()
    #expect(!model.matchInProgress)
}

@MainActor @Test func signInTrimsNameAndSetsSeatZero() throws {
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    #expect(!model.settings.hasSignedIn)
    model.signIn(name: "  Connor ", portrait: Cast.playerChoices[3], difficulty: .easy)
    #expect(model.settings.playerName == "Connor")
    #expect(model.seatNames[0] == "Connor")
    #expect(model.settings.playerPortrait == Cast.playerChoices[3])
    #expect(model.settings.difficulty == .easy)
    #expect(model.settings.hasSignedIn)
}

@MainActor @Test func seatSummaryIncludesSeatWord() throws {
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    #expect(model.seatSummary(for: 1).hasPrefix("Hazel, West, "))
    #expect(model.seatSummary(for: 3).hasSuffix("dealer"))
    #expect(model.seatSummary(for: 0).hasPrefix("You, "))
    #expect(model.seatSummary(for: 0).hasSuffix("to act"))
}

@Test func textBoostRaisesTheDefaultTwoStepsAndStopsAtTheLargest() {
    #expect(Theme.textBoostSteps == 2)
    #expect(DynamicTypeSize.large.boosted(by: Theme.textBoostSteps) == .xxLarge)
    #expect(DynamicTypeSize.accessibility5.boosted(by: Theme.textBoostSteps) == .accessibility5)
    #expect(DynamicTypeSize.xSmall.boosted(by: -3) == .xSmall)
    // Cards still stop at XXXL, so a user two steps below it is the last to see them grow.
    #expect(DynamicTypeSize.xLarge.boosted(by: Theme.textBoostSteps) == Theme.Card.maximumTypeSize)
}

@Test func dealtCardsComeFromTheDeckInTheCornerAndTheBandFrowns() {
    // The leftmost card has the longest flight from the top-right deck; the rightmost the shortest, still upward.
    let left = HandFanView.dealOrigin(index: 0, count: 6, width: 360)
    let right = HandFanView.dealOrigin(index: 5, count: 6, width: 360)
    #expect(left.width > right.width && right.width > 0)
    #expect(left.height < 0 && left.height == right.height)
    // The frown's middle sits `dip` above its corners.
    let band = HeaderBandShape(dip: 20).path(in: CGRect(x: 0, y: 0, width: 300, height: 100)).boundingRect
    #expect(band.maxY == 100 && band.minY == 0)
    #expect(Theme.Motion.dealHold > Theme.Motion.trickHold)
}

@MainActor @Test func rootOpensOnLoginUntilSignedInThenOnTheTable() {
    #expect(RootView.initialScreen(for: Settings()) == .login)
    #expect(RootView.initialScreen(for: Settings(hasSeenRules: true, playerName: "Connor")) == .table)
}


@Test func tablePauseHoldsWhileAnyCoverRemains() {
    var pause = TablePause()
    #expect(!pause.isPaused)
    pause.welcomeShown = true
    #expect(pause.isPaused)
    // A sheet opened over the welcome card: closing the sheet alone must not resume play.
    pause.sheetShown = true
    pause.sheetShown = false
    #expect(pause.isPaused)
    pause.welcomeShown = false
    #expect(!pause.isPaused)
    pause.sceneActive = false
    #expect(pause.isPaused)
    pause.sceneActive = true
    pause.dialogShown = true
    #expect(pause.isPaused)
    pause.dialogShown = false
    pause.inspectingTrick = true
    #expect(pause.isPaused)
    pause.inspectingTrick = false
    pause.drawShown = true
    #expect(pause.isPaused)
}

@MainActor @Test func saveFailureKeepsTheAcceptedMoveAndRetryWritesTheSameState() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    // The directory does not exist yet, so the first save fails.
    let url = directory.appendingPathComponent("game.json")
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3), saveURL: url)
    model.send(.bid(nil))
    #expect(model.match.actionCount == 1)
    #expect(model.lastHumanAction == .bid(nil))
    #expect(model.errorMessage == nil)
    #expect(model.saveError != nil)
    #expect(model.revision == 1)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    model.retrySave()
    #expect(model.saveError == nil)
    #expect(model.match.actionCount == 1)
    #expect(try MatchSave.read(from: url).actionCount == 1)
}

@Test func handLayoutFansOnlyWhenEveryStripIsThumbSized() {
    // Six 64 pt cards on the iPhone 16 (393 − 32 padding − 16 inset): a fan with the full overlap.
    #expect(HandLayout.arrange(count: 6, cardWidth: 64, available: 345) == .fan(strip: Theme.Card.touchStrip(width: 64)))
    // Cards grown by Dynamic Type still fan while every strip stays at 44 or more.
    #expect(HandLayout.arrange(count: 6, cardWidth: 120, available: 345) == .fan(strip: 45))
    // Any wider and the fan would hide part of a thumb target: two rows of three instead.
    let rows = HandLayout.arrange(count: 6, cardWidth: 130, available: 345)
    #expect(rows == .rows(perRow: 3, strip: 107.5))
    // Rows keep the invariant too, and never overlap more than the fan would.
    if case let .rows(perRow, strip) = rows { #expect(strip >= Theme.Card.minimumTouchStrip && perRow == 3) }
    // Fewer cards fan at any size; a single card needs no strip at all.
    #expect(HandLayout.arrange(count: 3, cardWidth: 100, available: 345) == .fan(strip: Theme.Card.touchStrip(width: 100)))
    #expect(HandLayout.arrange(count: 1, cardWidth: 100, available: 200) == .fan(strip: Theme.Card.touchStrip(width: 100)))
    // Height follows the arrangement so the hand never clips.
    #expect(HandLayout.height(of: .fan(strip: 56), cardWidth: 64) == 64 * Theme.Card.ratio + 16 + Theme.Card.fanDrop)
    #expect(HandLayout.height(of: .rows(perRow: 3, strip: 84), cardWidth: 100) == 2 * 100 * Theme.Card.ratio + 8 + 16)
}

@Test func seatRowLeavesRoomForThePileOnEveryVerifiedWidth() {
    // The pile's footprint: a card nudged toward either side seat, plus breathing room.
    let pile = TableLayout.pileReservation
    #expect(pile == Theme.Card.pileWidth + 2 * Theme.Table.sideNudge + 8)
    // iPhone 16 (393 − 32) and SE (375 − 32): the tiles give way before the pile can touch them.
    for available in [361.0, 343.0] {
        let tile = TableLayout.sideSeatWidth(available: available)
        #expect(tile <= Theme.Table.seatTileWidth)
        #expect(tile >= TableLayout.minimumSeatWidth)
        #expect(2 * tile + pile + 2 * TableLayout.seatGap <= available)
    }
    // Plenty of room: the tile keeps its full width.
    #expect(TableLayout.sideSeatWidth(available: 600) == Theme.Table.seatTileWidth)
}

@MainActor @Test func validationMessagesExplainRefusalsWithoutChangingTheMatch() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    // Your bid: a legal bid has no message; passing is legal too.
    #expect(model.validationMessage(for: .bid(2)) == nil)
    #expect(model.validationMessage(for: .bid(nil)) == nil)
    model.send(.bid(nil))
    let count = model.match.actionCount
    // Hazel is bidding now: anything you try waits for her, and nothing is recorded.
    #expect(model.validationMessage(for: .bid(3)) == "Wait for Hazel.")
    model.refuse(.bid(3))
    #expect(model.refusal == "Wait for Hazel.")
    #expect(model.match.actionCount == count)
    // Play until it is your turn to follow a computer's lead.
    var followed = false
    for _ in 0..<40 where !followed {
        if model.isHumanTurn {
            switch model.match.hand.phase {
            case .choosingTrump: model.send(.chooseTrump(model.humanCards[0].suit))
            case .playing:
                if let led = model.match.hand.currentTrick.first?.card.suit,
                   model.humanCards.contains(where: { $0.suit == led }),
                   let offSuit = model.humanCards.first(where: { $0.suit != led }) {
                    let before = model.match.actionCount
                    #expect(model.validationMessage(for: .play(offSuit)) == "Follow \(led.rawValue); you still have \(led.rawValue).")
                    #expect(model.match.actionCount == before)
                    followed = true
                } else {
                    model.send(.play(try #require(model.match.hand.legalMoves(seat: 0).first)))
                }
            default: model.send(.bid(nil))
            }
        } else {
            model.stepComputer()
        }
    }
    #expect(followed, "the fixed deck should make you follow suit at least once")
    // An accepted action clears the standing refusal.
    #expect(model.refusal == nil)
    #expect(model.validationMessage(for: .play(Card(.clubs, .two))) == nil || model.validationMessage(for: .play(Card(.clubs, .two))) == "That card is not in your hand.")
}

@MainActor @Test func dealerGetsBidContextAndNineAndOutStaysEngineChecked() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    // Dealer 3: you bid first and are not the dealer, so no context line.
    let early = GameModel(match: try Match(deck: deck, dealer: 3))
    #expect(early.auctionContext == nil)
    // Dealer 0: the three computers bid before you; the line explains matching or the forced 2.
    let model = GameModel(match: try Match(deck: deck, dealer: 0))
    #expect(model.auctionContext == nil)   // not your turn yet
    for _ in 0..<3 { model.stepComputer() }
    #expect(model.isHumanTurn)
    let context = try #require(model.auctionContext)
    if let high = model.match.hand.auction.highestBid {
        #expect(context == "As dealer you may match the high bid of \(high).")
    } else {
        #expect(context == "Everyone passed, so as dealer you must bid at least 2.")
    }
    // Confirming 9 and out still goes through the engine: after a pass it is refused, and nothing changes.
    model.send(.bid(nil))
    let count = model.match.actionCount
    #expect(!model.allows(.nineAndOut))
    model.send(.nineAndOut)
    #expect(model.match.actionCount == count)
    #expect(model.auctionContext == nil)
}

@Test func handOutcomeLeadsWithTheContractAndTheArithmetic() {
    let names = ["Connor", "Hazel", "Otto", "Rue"]
    // Made: you bid 4 and took 6, so 2 becomes 8; the defenders took 3, so 5 becomes 8.
    let made = HandOutcome(bidderTeam: 0, bid: 4, isNineAndOut: false, points: [6, 3], gameValues: [30, 20],
                           fiveTeam: 0, jackTeam: 1, before: [2, 5], after: [8, 8], names: names)
    #expect(made.headline == "Contract made")
    #expect(made.bidderLine == "Connor + Otto bid 4 · captured 6 · score 2 → 8")
    #expect(made.defenderLine == "Hazel + Rue captured 3 · score 5 → 8")
    #expect(made.notes.isEmpty)
    // Set: they bid 5 and took 3, so they lose the 5; you add your 6 as defenders.
    let set = HandOutcome(bidderTeam: 1, bid: 5, isNineAndOut: false, points: [6, 3], gameValues: [30, 20],
                          fiveTeam: 0, jackTeam: 0, before: [4, 10], after: [10, 5], names: names)
    #expect(set.headline == "Contract set")
    #expect(set.bidderLine == "Hazel + Rue bid 5 · captured 3 · score 10 → 5")
    #expect(set.defenderLine == "Connor + Otto captured 6 · score 4 → 10")
}

@Test func handOutcomeExplainsTheEdgeCases() {
    let names = ["Connor", "Hazel", "Otto", "Rue"]
    // A Game tie, the Five and Jack out of play, and both teams crossing 25 on the same hand.
    let tie = HandOutcome(bidderTeam: 0, bid: 3, isNineAndOut: false, points: [3, 1], gameValues: [14, 14],
                          fiveTeam: nil, jackTeam: nil, before: [23, 24], after: [26, 25], names: names)
    #expect(tie.notes == [
        "Game tied 14–14: the tie goes to the bidding team.",
        "The trump Five was not dealt, so its 5 points were out of play.",
        "The trump Jack was not dealt, so its point was out of play.",
        "Both teams reached 25: the bidding team wins the match.",
    ])
    // Nine and out, made and failed: the scores do not move, the match simply ends.
    let won = HandOutcome(bidderTeam: 1, bid: 9, isNineAndOut: true, points: [0, 9], gameValues: [0, 40],
                          fiveTeam: 1, jackTeam: 1, before: [10, 12], after: [10, 12], names: names)
    #expect(won.headline == "9 and out made")
    #expect(won.bidderLine == "Hazel + Rue bid 9 and out · captured all 9 · match won")
    #expect(won.defenderLine == "Connor + Otto captured 0 · scores unchanged")
    let lost = HandOutcome(bidderTeam: 0, bid: 9, isNineAndOut: true, points: [8, 1], gameValues: [40, 4],
                           fiveTeam: 0, jackTeam: 0, before: [10, 12], after: [10, 12], names: names)
    #expect(lost.headline == "9 and out failed")
    #expect(lost.bidderLine == "Connor + Otto bid 9 and out · captured 8 of 9 · match lost")
}

@MainActor @Test func lastHandOutcomeIsBuiltFromTheMatchHistory() throws {
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    #expect(model.lastHandOutcome == nil)
    try finishMatch(model)
    let outcome = try #require(model.lastHandOutcome)
    let last = try #require(model.match.history.last)
    #expect(outcome.headline == (last.contractMade ? (last.isNineAndOut ? "9 and out made" : "Contract made")
                                                   : (last.isNineAndOut ? "9 and out failed" : "Contract set")))
    let before = model.match.history.count > 1 ? model.match.history[model.match.history.count - 2].scores : [0, 0]
    #expect(outcome.bidderLine.contains("score \(before[last.bidder % 2]) → \(last.scores[last.bidder % 2])") || last.isNineAndOut)
}

@Test func oneFeedbackCuePerActionWithTheOutcomeThatMattersMost() {
    // A single tap can play a card, take a trick, end the hand and win the match at once; only one cue plays.
    #expect(TableFeedback.cue(action: .play, trickWinner: nil, handEnded: false, matchWinner: nil) == .play)
    #expect(TableFeedback.cue(action: .call, trickWinner: nil, handEnded: false, matchWinner: nil) == .call)
    #expect(TableFeedback.cue(action: .play, trickWinner: 0, handEnded: false, matchWinner: nil) == .trickWon)
    #expect(TableFeedback.cue(action: nil, trickWinner: 1, handEnded: false, matchWinner: nil) == .trickLost)
    #expect(TableFeedback.cue(action: .play, trickWinner: 2, handEnded: true, matchWinner: nil) == .handEnded)
    #expect(TableFeedback.cue(action: .play, trickWinner: 0, handEnded: true, matchWinner: 0) == .matchWon)
    #expect(TableFeedback.cue(action: .play, trickWinner: 1, handEnded: true, matchWinner: 1) == .matchLost)
    #expect(TableFeedback.cue(action: nil, trickWinner: nil, handEnded: false, matchWinner: nil) == nil)
}

@MainActor @Test func restoringALongReplayIsFastEnoughToNeedNoLoadingState() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    try finishMatch(model)
    // A finished match is at least two full hands of bids, trump and plays; the deck is shuffled, so the
    // exact length varies and a short match must not fail the timing check it exists for.
    #expect(model.match.actionCount >= 58)
    try MatchSave.write(model.match, to: url)
    let clock = ContinuousClock()
    let elapsed = try clock.measure { _ = try MatchSave.read(from: url) }
    // A whole match replays through the rules well inside the 300 ms the roadmap sets for showing a spinner.
    #expect(elapsed < .milliseconds(300), "restore took \(elapsed)")
}

@MainActor @Test func corruptGameIsSetAsideAndTheFreshGameSaysSo() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let game = directory.appendingPathComponent("game.json")
    try Data("not a game".utf8).write(to: game)
    let model = GameModel.loadDefault(in: directory)
    #expect(model.match.actionCount == 0)
    #expect(model.errorMessage?.contains("kept as game-corrupt.json") == true)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("game-corrupt.json").path))
    #expect(try String(contentsOf: directory.appendingPathComponent("game-corrupt.json"), encoding: .utf8) == "not a game")
    #expect(!FileManager.default.fileExists(atPath: game.path))
}

@MainActor @Test func resumeContextDescribesTheSavedMatch() throws {
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    #expect(model.resumeContext == nil)   // nothing has happened yet
    model.send(.bid(nil))
    #expect(model.resumeContext == "Hand 1 · Your team 0, their team 0 · bidding")
    try finishMatch(model)
    #expect(model.resumeContext == nil)   // a finished match is not something to resume
}

@MainActor @Test func trumpPreviewCountsWhatEachSuitKeepsAndDraws() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    #expect(model.trumpPreview(for: .hearts) == nil)   // only while you are choosing trump
    model.send(.bid(9))
    for _ in 0..<3 { model.stepComputer() }
    #expect(model.match.hand.phase == .choosingTrump && model.isHumanTurn)
    for suit in Suit.allCases {
        let held = model.humanCards.filter { $0.suit == suit }.count
        #expect(model.trumpPreview(for: suit) == "keep \(held) · draw \(6 - held)")
    }
    // The previews are honest: choosing a suit discards exactly what the preview said.
    let suit = try #require(Suit.allCases.max { a, b in model.humanCards.filter { $0.suit == a }.count < model.humanCards.filter { $0.suit == b }.count })
    let kept = model.humanCards.filter { $0.suit == suit }.count
    model.send(.chooseTrump(suit))
    #expect(model.notice == (kept == 6 ? "You kept all six cards." : "You discarded \(6 - kept) and drew \(6 - kept)."))
}

@Test func rootRoutesSignedInPlayersWhoSkippedTheIntroBackToIt() {
    var settings = Settings(playerName: "Connor")
    #expect(RootView.initialScreen(for: settings) == .intro)   // signed in, never saw the intro or rules
    settings.hasSeenRules = true
    #expect(RootView.initialScreen(for: settings) == .table)
    #expect(RootView.initialScreen(for: Settings()) == .login)
}

@Test func signingInKeepsAMatchAnExistingInstallLeftInProgress() {
    // An older install with a saved match reaches the welcome card, not a silent new deal.
    #expect(RootView.destinationAfterSignIn(matchInProgress: true, hasSeenRules: true) == .welcome)
    #expect(RootView.destinationAfterSignIn(matchInProgress: true, hasSeenRules: false) == .welcome)
    #expect(RootView.destinationAfterSignIn(matchInProgress: false, hasSeenRules: false) == .intro)
    #expect(RootView.destinationAfterSignIn(matchInProgress: false, hasSeenRules: true) == .table)
}

@Test func settingsToleratesValuesItDoesNotRecogniseAndMigratesOnlyPreCastFiles() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    // A portrait case from a newer build must not sign the player out.
    try Data(#"{"playerName":"Connor","playerPortrait":{"skin":"violet","hair":"bob","hairColor":"silver","feature":"none","hat":"none","shirt":"plum"},"playSpeed":"warp","difficulty":"brutal"}"#.utf8).write(to: url)
    let tolerant = try SettingsStore.read(from: url)
    #expect(tolerant.playerName == "Connor" && tolerant.hasSignedIn)
    #expect(tolerant.playerPortrait == Cast.defaultPlayerPortrait && tolerant.playSpeed == .normal && tolerant.difficulty == .standard)
    // A file written after sign-in keeps a deliberately typed "West"; only pre-cast files migrate.
    try Data(#"{"playerName":"Connor","seatNames":["Connor","West","Otto","Rue"]}"#.utf8).write(to: url)
    #expect(try SettingsStore.read(from: url).seatNames == ["Connor", "West", "Otto", "Rue"])
    try Data(#"{"seatNames":["You","West","Partner","East"]}"#.utf8).write(to: url)
    #expect(try SettingsStore.read(from: url).seatNames == ["You", "Hazel", "Otto", "Rue"])
    // One place writes the player's name, with one trim rule.
    var settings = Settings()
    settings.setPlayerName("  Mum ")
    #expect(settings.playerName == "Mum" && settings.seatNames[0] == "Mum")
    settings.setPlayerName("   ")
    #expect(settings.playerName == "Mum" && settings.seatNames[0] == "Mum")
}

@MainActor @Test func corruptSettingsAreSetAsideAndReported() throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    try Data("{not json".utf8).write(to: directory.appendingPathComponent("settings.json"))
    let model = GameModel.loadDefault(in: directory)
    #expect(!model.settings.hasSignedIn)
    #expect(model.errorMessage?.contains("settings-corrupt.json") == true)
    #expect(FileManager.default.fileExists(atPath: directory.appendingPathComponent("settings-corrupt.json").path))
}

@MainActor @Test func feedbackSnapshotOfARestoredMatchProducesNoCue() throws {
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    try finishMatch(model)
    model.newGame()
    // Play into the second hand so history and tricks are non-zero, as a restored match would be.
    for _ in 0..<60 where model.match.hand.completedTricks.count < 2 {
        if model.isHumanTurn {
            switch model.match.hand.phase {
            case .bidding: model.send(.bid(model.allows(.bid(3)) ? 3 : nil))
            case .choosingTrump: model.send(.chooseTrump(model.humanCards[0].suit))
            case .playing: model.send(.play(try #require(model.match.hand.legalMoves(seat: 0).first)))
            default: break
            }
        } else { model.stepComputer() }
    }
    let restored = TableFeedback.Snapshot(model)
    #expect(TableFeedback.cue(from: restored, to: TableFeedback.Snapshot(model)) == nil)
    // The next human play is a play, not a phantom hand end.
    while !model.isHumanTurn || model.match.hand.phase != .playing { model.stepComputer() }
    let before = TableFeedback.Snapshot(model)
    model.send(.play(try #require(model.match.hand.legalMoves(seat: 0).first)))
    let cue = TableFeedback.cue(from: before, to: TableFeedback.Snapshot(model))
    #expect(cue == .play || cue == .trickWon || cue == .trickLost)
}

@Test func seatMoodsFollowPublicEventsOnly() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var match = try Match(deck: deck, dealer: 3)
    // Fresh hand: seat 0 is to bid, so seat 0 thinks and the others are neutral.
    #expect(SeatMood.expression(for: 0, in: match) == .thinking)
    #expect(SeatMood.expression(for: 1, in: match) == .neutral)
    try match.bid(seat: 0, amount: 9)
    #expect(SeatMood.expression(for: 1, in: match) == .thinking)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    // Play one trick out; the winning team is pleased and the other rueful until the next lead.
    for _ in 0..<4 {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    let winner = try #require(match.hand.completedTricks.last?.winner)
    for seat in 0..<4 where seat != match.hand.nextSeat {
        #expect(SeatMood.expression(for: seat, in: match) == (seat % 2 == winner % 2 ? .pleased : .rueful))
    }
    #expect(SeatMood.expression(for: try #require(match.hand.nextSeat), in: match) == .thinking)
    // Once the next trick starts, the reaction is over.
    let leader = try #require(match.hand.nextSeat)
    try match.play(seat: leader, card: try #require(match.hand.legalMoves(seat: leader).first))
    for seat in 0..<4 where seat != match.hand.nextSeat { #expect(SeatMood.expression(for: seat, in: match) == .neutral) }
    // The verdict on a finished match is the loudest expression of all.
    #expect(SeatMood.expression(for: 1, in: match, matchWinner: 1) == .triumphant)
    #expect(SeatMood.expression(for: 2, in: match, matchWinner: 1) == .dismayed)
}

@Test func tossedCardsLandDifferentlyButStayPut() {
    // The same card in the same trick of the same hand always lands the same way, so a re-render never nudges it.
    let ace = Card(.spades, .ace), five = Card(.hearts, .five)
    let pose = CardToss.pose(for: ace, hand: 3, trick: 2)
    #expect(pose == CardToss.pose(for: ace, hand: 3, trick: 2))
    // Different cards, or the same card in another hand, land differently.
    #expect(pose != CardToss.pose(for: five, hand: 3, trick: 2))
    #expect(pose != CardToss.pose(for: ace, hand: 4, trick: 2))
    // Every pose stays within a hand's-throw of the seat's spot and never turns a card past readable.
    for hand in 1...12 {
        for trick in 0...5 {
            for suit in Suit.allCases {
                for rank in Rank.allCases {
                    let p = CardToss.pose(for: Card(suit, rank), hand: hand, trick: trick)
                    #expect(abs(p.rotation) <= Theme.Table.tossRotationDegrees)
                    #expect(abs(p.offset.width) <= Theme.Table.tossDrift && abs(p.offset.height) <= Theme.Table.tossDrift)
                }
            }
        }
    }
    // The spread is real: over a hand's worth of cards the rotations are not all on one side.
    let rotations = Rank.allCases.map { CardToss.pose(for: Card(.clubs, $0), hand: 1, trick: 0).rotation }
    #expect(rotations.contains { $0 > 2 } && rotations.contains { $0 < -2 })
}

@MainActor @Test func statusSaysWhichSuitYouMustFollow() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    #expect(model.suitToFollow == nil)   // nothing led yet
    model.send(.bid(nil))
    for _ in 0..<40 where model.suitToFollow == nil {
        if model.isHumanTurn {
            switch model.match.hand.phase {
            case .choosingTrump: model.send(.chooseTrump(model.humanCards[0].suit))
            case .playing: model.send(.play(try #require(model.match.hand.legalMoves(seat: 0).first)))
            default: model.send(.bid(nil))
            }
        } else { model.stepComputer() }
    }
    let led = try #require(model.suitToFollow)
    #expect(model.match.hand.currentTrick.first?.card.suit == led)
    #expect(model.humanCards.contains { $0.suit == led })
    // Only your own turn, and only while you hold the led suit.
    #expect(model.isHumanTurn)
    #expect(model.match.hand.legalMoves(seat: 0).allSatisfy { $0.suit == led })
}

@Test func discardsFlyToThePileUnderTheDeck() {
    // Discards head for the top-right corner like the deal, but land lower: under the deck, not on it.
    for index in 0..<6 {
        let deal = HandFanView.dealOrigin(index: index, count: 6, width: 360)
        let discard = HandFanView.discardTarget(index: index, count: 6, width: 360)
        #expect(discard.width == deal.width)             // same corner
        #expect(discard.height < 0 && discard.height > deal.height)   // upward, but not as far
    }
    #expect(Theme.Table.discardDrop > Theme.Table.deckWidth * Theme.Card.ratio)   // clear of the deck itself
}

@Test func dealerDrawPicksTheHighestCardWithSuitsBreakingTies() {
    // Seats 0 to 3 draw the first four cards; the highest rank deals, and equal ranks go by suit.
    let draw = DealerDraw.draw(from: [Card(.hearts, .nine), Card(.spades, .king), Card(.clubs, .king), Card(.diamonds, .two)] + [])
    #expect(draw.cards.count == 4 && draw.dealer == 1)   // king of spades beats king of clubs
    #expect(DealerDraw.draw(from: [Card(.clubs, .ace), Card(.spades, .king), Card(.hearts, .queen), Card(.diamonds, .jack)]).dealer == 0)
    #expect(DealerDraw.draw(from: [Card(.clubs, .five), Card(.diamonds, .five), Card(.hearts, .five), Card(.spades, .five)]).dealer == 3)
    #expect(DealerDraw.ranking(Card(.spades, .two)) > DealerDraw.ranking(Card(.clubs, .two)))
    #expect(DealerDraw.ranking(Card(.clubs, .three)) > DealerDraw.ranking(Card(.spades, .two)))
}

@MainActor @Test func newGameDrawsForDealerAndTheMatchUsesIt() throws {
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3))
    #expect(model.dealerDraw == nil)
    model.newGame()
    let draw = try #require(model.dealerDraw)
    #expect(model.match.hand.auction.dealer == draw.dealer)
    #expect(Set(draw.cards).count == 4)
    // The draw is a picture of how the deal was decided; the first action puts it away.
    #expect(model.match.actionCount == 0)
    model.dismissDealerDraw()
    #expect(model.dealerDraw == nil)
    model.newGame()
    let seat = try #require(model.match.hand.nextSeat)
    if seat == 0 { model.send(.bid(nil)) } else { model.stepComputer() }
    #expect(model.dealerDraw == nil)
}

@Test func theRulesSayHowTheFirstDealerIsChosen() {
    #expect(RulesText.sections[0].paragraphs.count == 2)
    #expect(RulesText.sections[0].paragraphs[1].contains("highest deals"))
}

@Test func rulesFiguresMatchTheEngine() throws {
    // The scoring tiles add up to the nine points a hand can hold, and the Game ledger quotes the engine's values.
    #expect(RulesFigures.pointTiles.map(\.points).reduce(0, +) == 9)
    #expect(RulesFigures.pointTiles.map(\.name) == ["High", "Low", "Jack", "Five", "Game"])
    for entry in RulesFigures.gameValues { #expect(entry.value == entry.rank.gameValue) }
    #expect(RulesFigures.gameValues.map(\.rank) == [.ten, .ace, .king, .queen, .jack])
    // The two example tricks are judged by the real rule, not drawn by hand.
    #expect(try trickWinner(RulesFigures.followedTrick, trump: RulesFigures.trump) == RulesFigures.followedWinner)
    #expect(try trickWinner(RulesFigures.trumpedTrick, trump: RulesFigures.trump) == RulesFigures.trumpedWinner)
    #expect(RulesFigures.followedWinner != RulesFigures.trumpedWinner)
    // The ladder and the target quote the engine's named house numbers, not literals of their own.
    #expect(RulesFigures.bidLadder == Array(HouseRules.bidRange))
    #expect(RulesFigures.matchTarget == HouseRules.matchTarget)
    #expect(RulesFigures.nineAndOutPoints == HouseRules.handPoints)
    // The captions are built from the drawn cards, so they can never disagree with the figure.
    #expect(RulesFigures.caption(trumped: false).contains("king of hearts"))
    #expect(RulesFigures.caption(trumped: false).contains("two of clubs"))
    #expect(RulesFigures.caption(trumped: true).contains("four of spades"))
}

@Test func rulesChaptersMatchTheRuleSectionsByTitle() {
    // Every rule section has a chapter of the same title, in order; the last chapter is the screen notes.
    let chapters = RulesView.Chapter.allCases
    #expect(chapters.dropLast().map(\.title) == RulesText.sections.map(\.title))
    for chapter in chapters.dropLast() {
        #expect(chapter.paragraphs == RulesText.sections.first { $0.title == chapter.title }?.paragraphs)
    }
    #expect(chapters.last?.paragraphs == RulesText.readingTheTable)
    #expect(Set(chapters.map(\.numeral)).count == chapters.count)
}

@Test func houseRuleNumbersAreTheOnesTheEngineEnforces() throws {
    // settle() and the auction use the named constants; a change there must show here.
    #expect(HouseRules.matchTarget == 25 && HouseRules.bidRange == 2...9 && HouseRules.handPoints == 9)
    let reached = try settle(scores: [HouseRules.matchTarget - 1, 0], points: [HouseRules.bidRange.lowerBound, 0], bidder: 0, bid: .points(HouseRules.bidRange.lowerBound))
    #expect(reached.winner == 0)
    #expect(throws: RuleError.invalidBid) { try settle(scores: [0, 0], points: [1, 0], bidder: 0, bid: .points(HouseRules.bidRange.upperBound + 1)) }
}

@Test func ruleTrialsAreJudgedByTheEngine() throws {
    // Follow suit: hearts led, you hold hearts, spades are trump.
    var follow = RuleTrial.make(.followSuit)
    let hand = follow.offeredCards
    #expect(hand.count == 6 && hand.filter { $0.suit == .hearts }.count == 2 && hand.filter { $0.suit == .spades }.count == 2)
    #expect(follow.match.hand.currentTrick.first?.card.suit == .hearts && follow.match.hand.trump == .spades)
    let offSuit = try #require(hand.first { $0.suit == .clubs })
    let trump = try #require(hand.first { $0.suit == .spades })
    let heart = try #require(hand.first { $0.suit == .hearts })
    #expect(follow.attempt(.play(offSuit)) == .refused("Follow hearts; you still have hearts."))
    #expect(follow.attempt(.play(trump)) == .refused("Follow hearts; you still have hearts."))
    guard case let .accepted(text) = follow.attempt(.play(heart)) else { Issue.record("a heart is legal"); return }
    #expect(text.contains("the trick with the"))
    // Refusals never moved the position; an acceptance plays the trick out; reset brings it back.
    #expect(follow.match.hand.completedTricks.count == 1)
    follow.reset()
    #expect(follow.match.hand.completedTricks.isEmpty && follow.match.hand.currentTrick.count == 3)

    // The dealer may match: Hazel bid 3, you are dealer.
    var dealer = RuleTrial.make(.dealerMatch)
    #expect(dealer.match.hand.auction.highestBid == 3 && dealer.match.hand.nextSeat == 0)
    #expect(dealer.offeredActions == [.bid(nil), .bid(2), .bid(3), .bid(4)])
    if case .refused = dealer.attempt(.bid(2)) {} else { Issue.record("2 cannot beat 3") }
    guard case let .accepted(matched) = dealer.attempt(.bid(3)) else { Issue.record("the dealer may match"); return }
    #expect(matched.contains("match"))
    dealer.reset()
    guard case let .accepted(passed) = dealer.attempt(.bid(nil)) else { Issue.record("passing is legal"); return }
    #expect(passed.contains("Hazel"))

    // 9 and out below zero: a failed 9 last hand left you at -9.
    var nine = RuleTrial.make(.nineAndOutBelowZero)
    #expect(nine.match.scores[0] < 0 && nine.match.hand.nextSeat == 0)
    #expect(nine.attempt(.nineAndOut) == .refused(GameModel.message(for: RuleError.forbiddenNineAndOut)))
    if case .accepted = nine.attempt(.bid(2)) {} else { Issue.record("a normal bid is still allowed") }
}

@MainActor @Test func ruleTrialsLeaveTheOngoingMatchAndItsSaveAlone() throws {
    // A practice position is its own Match: entering, playing, resetting and leaving it must not touch
    // the live game, its replay log on disk, its scores or its history.
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: url) }
    let model = GameModel(match: try Match(deck: GameModel.deck(), dealer: 3), saveURL: url)
    model.send(.bid(nil))
    let before = (model.match.actionCount, model.match.scores, model.match.history.count, model.revision, try Data(contentsOf: url))
    for kind in RuleTrial.Kind.allCases {
        var trial = RuleTrial.make(kind)
        for card in trial.offeredCards { trial.attempt(.play(card)) }
        for action in trial.offeredActions { trial.attempt(action) }
        trial.reset()
    }
    #expect(model.match.actionCount == before.0 && model.match.scores == before.1 && model.match.history.count == before.2)
    #expect(model.revision == before.3)
    #expect(try Data(contentsOf: url) == before.4)
}

@Test func hintSplitsIntoARecommendationAndItsReason() {
    let parts = TableSurface.hintParts("Play the six of clubs: partner's queen of clubs holds the trick, so the most valuable card goes to it.")
    #expect(parts.recommendation == "Play the six of clubs")
    #expect(parts.detail == "Partner's queen of clubs holds the trick, so the most valuable card goes to it.")
    #expect(TableSurface.hintParts("Pass").recommendation == "Pass" && TableSurface.hintParts("Pass").detail.isEmpty)
}

