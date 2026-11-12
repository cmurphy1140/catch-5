import CatchFive
@testable import CatchFiveUI
import Testing

private func privacyPosition(changedHiddenCard: Bool = false) throws -> Match {
    var deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    if changedHiddenCard { deck.swapAt(26, 40) }
    var match = try Match(deck: deck, dealer: 3)
    try match.bid(seat: 0, amount: 2)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    for play in [Play(seat: 0, card: Card(.clubs, .two)), Play(seat: 1, card: Card(.clubs, .five)),
                 Play(seat: 2, card: Card(.clubs, .eight)), Play(seat: 3, card: Card(.clubs, .jack)),
                 Play(seat: 3, card: Card(.hearts, .eight))] {
        try match.play(seat: play.seat, card: play.card)
    }
    return match
}

@MainActor @Test func opponentPrivateExplanationWaitsUntilTheHandIsFinished() throws {
    var match = try privacyPosition()
    let opponent = try #require(match.hand.currentTrick.first)
    let live = GameModel(match: match)
    #expect(opponent.seat == 3 && live.viewerSeat == 0 && live.isHumanTurn)
    #expect(live.explanation(for: opponent, inLastTrick: false) == nil)
    let own = try #require(match.hand.completedTricks.first?.plays.first)
    #expect(live.explanation(for: own, inLastTrick: false, trickIndex: 0) != nil)
    while match.hand.phase == .playing {
        let seat = try #require(match.hand.nextSeat)
        try match.play(seat: seat, card: try #require(match.hand.legalMoves(seat: seat).first))
    }
    let finished = GameModel(match: match)
    #expect(finished.explanation(for: opponent, inLastTrick: false, trickIndex: 1) != nil)
}

@MainActor @Test func liveAdviceIgnoresGenuinelyDifferentHiddenHandsAndStock() throws {
    let a = try privacyPosition(), b = try privacyPosition(changedHiddenCard: true)
    #expect(a.hand.hands[1] != b.hand.hands[1])
    #expect(a.hand.stock != b.hand.stock)
    let av = try PlayerView(match: a, seat: 0), bv = try PlayerView(match: b, seat: 0)
    #expect(av.cards == bv.cards && av.phase == bv.phase && av.nextSeat == bv.nextSeat)
    #expect(av.dealer == bv.dealer && av.highestBid == bv.highestBid && av.bidder == bv.bidder)
    #expect(av.trump == bv.trump && av.trick == bv.trick && av.calls == bv.calls)
    #expect(av.completedTricks.map(\.plays) == bv.completedTricks.map(\.plays) && av.completedTricks.map(\.winner) == bv.completedTricks.map(\.winner) && av.discardCounts == bv.discardCounts && av.scores == bv.scores)
    let model = GameModel(match: a), other = GameModel(match: b)
    let before = model.match
    let left = try #require(model.liveAdvice()), right = try #require(other.liveAdvice())
    #expect(left.advice.action == right.advice.action && left.advice.reason == right.advice.reason)
    #expect(left.advice == ComputerPlayer.advise(av))
    #expect(model.match.actionCount == before.actionCount && model.match.hand.hands == before.hand.hands)
    #expect(!left.actionTitle.isEmpty && !left.rules.isEmpty)
    #expect(left.viewerSeat == 0 && left.revision == model.revision)
    #expect(left.isValid(for: model) && !left.isValid(for: other))
    #expect(!left.isValid(for: model, covered: true) && model.liveAdvice(covered: true) == nil)
    model.send(left.advice.action)
    #expect(!left.isValid(for: model) && model.liveAdvice() == nil)
    model.undo()
    #expect(model.viewerSeat == left.viewerSeat && model.isHumanTurn)
    #expect(model.revision != left.revision && !left.isValid(for: model))
    #expect(model.liveAdvice()?.advice == left.advice)
}

@MainActor @Test func liveAdviceCurtainViewerAndRevisionInvalidation() throws {
    let model = GameModel(match: try privacyPosition(), mode: .passAndPlay)
    #expect(model.viewerSeat == nil && model.liveAdvice() == nil)
    let own = try #require(model.match.hand.completedTricks.first?.plays.first)
    #expect(model.explanation(for: own, inLastTrick: false, trickIndex: 0) == nil)
    model.ready()
    let presentation = try #require(model.liveAdvice())
    #expect(presentation.isValid(for: model))
    model.send(presentation.advice.action)
    #expect(model.curtainSeat != nil && !presentation.isValid(for: model))
    #expect(model.liveAdvice() == nil)
    #expect(model.explanation(for: own, inLastTrick: false, trickIndex: 0) == nil)
    model.ready()
    #expect(model.viewerSeat == 1 && model.liveAdvice() != nil)
    #expect(!presentation.isValid(for: model))
}

@MainActor @Test func liveAdviceWorksAcrossBiddingTrumpAndPlayWithoutExecutingMoves() throws {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    let model = GameModel(match: try Match(deck: deck, dealer: 3))
    let bid = try #require(model.liveAdvice())
    #expect(bid.rules.contains(.bidding))
    model.send(.bid(9))
    #expect(!bid.isValid(for: model) && model.liveAdvice() == nil)
    for _ in 0..<3 { model.stepComputer() }
    let trump = try #require(model.liveAdvice())
    #expect(trump.rules.contains(.discardAndRefill))
    model.send(.chooseTrump(.clubs))
    let play = try #require(model.liveAdvice())
    #expect(play.rules.contains(.openingTrump))
    while model.match.hand.phase == .playing {
        if model.isHumanTurn { model.send(.play(try #require(model.match.hand.legalMoves(seat: 0).first))) }
        else { model.stepComputer() }
    }
    #expect(model.liveAdvice() == nil && !play.isValid(for: model))
}
