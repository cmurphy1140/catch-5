public enum HandReplayError: Error, Equatable {
    case handNotFinished, handNotFound
}

/// References to the existing house rules, kept separate from any strategy suggestion.
public enum ReplayRule: String, CaseIterable, Sendable {
    case bidding, dealerMatch, discardAndRefill, openingTrump, followSuit
    case trumpWins, ledSuitWins, highLowPlayed, capturedScoring, gameTie
    case ordinarySettlement, nineAndOut, targetScore
}

public enum ReplayEvent: Equatable, Sendable {
    case deal(dealer: Int)
    case bid(seat: Int, bid: Bid?)
    case trump(seat: Int, suit: Suit)
    case discard(seat: Int, thrown: [Card], drawn: [Card])
    case play(Play)
    case trick(number: Int, plays: [Play], winner: Int)
    case score(before: [Int], after: [Int], result: HandScore, winner: Int?, nineAndOut: Bool)
}

/// The historical cards and scores at one event. A fourth-card play and its award show the complete trick;
/// scoring is a separate event, so its new totals never appear before the hand is settled.
public struct ReplayStep: Equatable, Sendable, Identifiable {
    public let id: Int
    public let event: ReplayEvent
    public let hands: [[Card]]
    public let currentTrick: [Play]
    public let scores: [Int]
    public let rules: [ReplayRule]
}

/// A completed hand, rebuilt once from accepted actions. A later live hand is never included in the snapshot.
/// All four historical hands may be revealed here; live suggestions still use only PlayerView.
public struct HandReplay: Sendable {
    public let number: Int
    public let dealer: Int
    public let bidder: Int
    public let bid: Int
    public let isNineAndOut: Bool
    public let trump: Suit
    public let before: [Int]
    public let after: [Int]
    public let winner: Int?
    /// The original shuffled deck, retained for exact-deal practice, not for displaying undealt cards.
    public let deal: [Card]
    public let dealStartActionCount: Int
    public let finishedMatch: Match
    public let steps: [ReplayStep]

    public init(match: Match, handNumber: Int? = nil) throws {
        let target = handNumber ?? match.handNumber
        guard target > 0, target <= match.handNumber else { throw HandReplayError.handNotFound }
        guard match.history.contains(where: { $0.number == target }) else { throw HandReplayError.handNotFinished }

        var cursor = try Match(deck: match.initialDeck, dealer: match.initialDealer)
        var events: [ReplayStep] = []
        var deck = match.initialDeck
        var start = 0
        var completed: Match?

        func append(_ event: ReplayEvent, hands: [[Card]], trick: [Play] = [], scores: [Int], rules: [ReplayRule]) {
            events.append(ReplayStep(id: events.count, event: event, hands: hands,
                                     currentTrick: trick, scores: scores, rules: rules))
        }

        if target == 1 {
            append(.deal(dealer: cursor.hand.auction.dealer), hands: cursor.hand.hands,
                   scores: cursor.scores, rules: [.bidding])
        }

        for (index, action) in match.actions.enumerated() {
            let oldHand = cursor.hand
            let oldScores = cursor.scores
            try action.apply(to: &cursor)

            if case let .nextHand(nextDeck) = action {
                if cursor.handNumber == target {
                    deck = nextDeck
                    start = index + 1
                    append(.deal(dealer: cursor.hand.auction.dealer), hands: cursor.hand.hands,
                           scores: cursor.scores, rules: [.bidding])
                }
                continue
            }
            guard cursor.handNumber == target else { continue }

            switch action {
            case let .bid(seat, amount):
                var rules: [ReplayRule] = [.bidding]
                if seat == oldHand.auction.dealer, let amount, amount == oldHand.auction.highestBid {
                    rules.append(.dealerMatch)
                }
                if oldHand.auction.isNineAndOut { rules.append(.nineAndOut) }
                append(.bid(seat: seat, bid: amount.map(Bid.points)), hands: cursor.hand.hands,
                       scores: oldScores, rules: rules)
            case let .nineAndOut(seat):
                append(.bid(seat: seat, bid: .nineAndOut), hands: cursor.hand.hands,
                       scores: oldScores, rules: [.bidding, .nineAndOut])
            case let .trump(seat, suit):
                append(.trump(seat: seat, suit: suit), hands: oldHand.hands,
                       scores: oldScores, rules: [.bidding])
                // The engine performs these in one action; show its automatic per-seat discard/refill order.
                var hands = oldHand.hands
                for offset in 1...4 {
                    let player = (oldHand.auction.dealer + offset) % 4
                    let thrown = hands[player].filter { $0.suit != suit }
                    let kept = hands[player].count - thrown.count
                    let drawn = Array(cursor.hand.hands[player].dropFirst(kept))
                    hands[player] = cursor.hand.hands[player]
                    append(.discard(seat: player, thrown: thrown, drawn: drawn), hands: hands,
                           scores: oldScores, rules: [.discardAndRefill])
                }
            case let .play(seat, card):
                let play = Play(seat: seat, card: card)
                let trick = oldHand.currentTrick + [play]
                var rules: [ReplayRule] = []
                if let led = oldHand.currentTrick.first?.card.suit {
                    if oldHand.hands[seat].contains(where: { $0.suit == led }) { rules.append(.followSuit) }
                } else if oldHand.completedTricks.isEmpty,
                          oldHand.hands[seat].contains(where: { $0.suit == oldHand.trump }) {
                    rules.append(.openingTrump)
                }
                append(.play(play), hands: cursor.hand.hands, trick: trick, scores: oldScores, rules: rules)
                if cursor.hand.completedTricks.count > oldHand.completedTricks.count,
                   let awarded = cursor.hand.completedTricks.last {
                    let wonWithTrump = awarded.plays.contains { $0.card.suit == cursor.hand.trump }
                    append(.trick(number: cursor.hand.completedTricks.count, plays: awarded.plays, winner: awarded.winner),
                           hands: cursor.hand.hands, trick: awarded.plays, scores: oldScores,
                           rules: [wonWithTrump ? .trumpWins : .ledSuitWins])
                }
                if cursor.hand.phase == .finished, let result = cursor.hand.result {
                    var scoring: [ReplayRule] = [.highLowPlayed, .capturedScoring]
                    if result.gameValues[0] == result.gameValues[1] { scoring.append(.gameTie) }
                    scoring.append(cursor.hand.auction.isNineAndOut ? .nineAndOut : .ordinarySettlement)
                    if !cursor.hand.auction.isNineAndOut, cursor.winner != nil { scoring.append(.targetScore) }
                    append(.score(before: oldScores, after: cursor.scores, result: result,
                                  winner: cursor.winner, nineAndOut: cursor.hand.auction.isNineAndOut),
                           hands: cursor.hand.hands, scores: cursor.scores, rules: scoring)
                    completed = cursor
                }
            case .nextHand:
                break
            }
            if completed != nil { break }
        }

        guard let completed, let summary = completed.history.last, let suit = completed.hand.trump else {
            throw HandReplayError.handNotFinished
        }
        number = target
        dealer = summary.dealer
        bidder = summary.bidder
        bid = summary.bid
        isNineAndOut = summary.isNineAndOut
        trump = suit
        before = completed.scoresBeforeHand
        after = completed.scores
        winner = completed.winner
        deal = deck
        dealStartActionCount = start
        finishedMatch = completed
        steps = events
    }

    /// Starts the same deal as a new match; no original scores, history or accepted actions carry over.
    public func practiceMatch() throws -> Match {
        try Match(deck: deal, dealer: dealer)
    }
}

extension Match {
    /// The accepted-action count immediately after the current hand was dealt, or zero for the first deal.
    public var handStartActionCount: Int {
        guard let index = actions.lastIndex(where: { if case .nextHand = $0 { true } else { false } }) else { return 0 }
        return index + 1
    }
}
