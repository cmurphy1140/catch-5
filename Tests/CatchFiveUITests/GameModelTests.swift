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

@Test func explainerPagesAreBundledTogether() throws {
    // The pages link to each other by file name, so the folder must hold every one the library lists.
    let folder = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        .appendingPathComponent("App/Explainer")
    let files = try FileManager.default.contentsOfDirectory(atPath: folder.path).filter { $0.hasSuffix(".dc.html") }
    #expect(files.count == 10)
    for page in ExplainerLibrary.pages {
        let url = folder.appendingPathComponent("\(page).dc.html")
        #expect(FileManager.default.fileExists(atPath: url.path), "missing \(page)")
        let data = try Data(contentsOf: url)
        #expect(data.count > 50_000)
        // Self-contained: no script or stylesheet fetched from the network.
        let head = String(decoding: data.prefix(20_000), as: UTF8.self)
        #expect(!head.contains("src=\"http") && !head.contains("href=\"http"), "\(page) references the network")
    }
    #expect(ExplainerLibrary.pages.first == ExplainerLibrary.indexPage)
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
    #expect(RootView.initialScreen(for: Settings(playerName: "Connor")) == .table)
}

