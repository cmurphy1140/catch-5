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
    #expect(model.contract == "\(GameModel.seatNames[bidder]) bid \(bid)")
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
