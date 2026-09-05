public enum ReviewError: Error, Equatable {
    /// The strategy had no advice for a play, which cannot happen for a legal play in a playing phase.
    case unexplainedPlay
}

/// One play of a finished hand alongside what the standard strategy would have done from the same view.
public struct PlayReview: Equatable, Sendable {
    public let play: Play
    public let advice: Advice
    public var agreed: Bool { advice.action == .play(play.card) }

    public init(play: Play, advice: Advice) {
        self.play = play
        self.advice = advice
    }
}

public struct TrickReview: Equatable, Sendable {
    public let number: Int
    public let winner: Int
    public let plays: [PlayReview]
}

/// Every play of the current hand's completed tricks, explained by rebuilding each seat's view (see D24).
public struct HandReview: Equatable, Sendable {
    public let tricks: [TrickReview]

    public init(match: Match) throws {
        var tricks: [TrickReview] = []
        for (index, trick) in match.hand.completedTricks.enumerated() {
            let plays = try trick.plays.map { play in
                let view = try PlayerView(match: match, replaying: play, inCompletedTrick: index)
                guard let advice = ComputerPlayer.advise(view) else { throw ReviewError.unexplainedPlay }
                return PlayReview(play: play, advice: advice)
            }
            tricks.append(TrickReview(number: index + 1, winner: trick.winner, plays: plays))
        }
        self.tricks = tricks
    }

    /// How often `seat` played the card the standard strategy would have chosen.
    public func agreement(forSeat seat: Int) -> (agreed: Int, total: Int) {
        let plays = tricks.flatMap(\.plays).filter { $0.play.seat == seat }
        return (plays.filter(\.agreed).count, plays.count)
    }
}

/// A seat's record over a whole match, rebuilt from the action log so nothing extra needs saving.
public struct SeatPerformance: Equatable, Sendable {
    public let plays: Int
    public let playsAgreed: Int
    public let bids: Int
    public let bidsMade: Int

    public init(plays: Int, playsAgreed: Int, bids: Int, bidsMade: Int) {
        self.plays = plays
        self.playsAgreed = playsAgreed
        self.bids = bids
        self.bidsMade = bidsMade
    }
}

extension Match {
    /// Replays the match hand by hand and reviews each finished hand for `seat`.
    public func performance(forSeat seat: Int) throws -> SeatPerformance {
        var plays = 0, agreed = 0
        // Each `.nextHand` action marks a finished hand; the current hand counts once it is scored.
        var boundaries = actions.indices.filter { if case .nextHand = actions[$0] { true } else { false } }
        if hand.phase == .finished { boundaries.append(actions.count) }
        for boundary in boundaries {
            // The current finished hand is this match already; earlier hands are rebuilt by replay.
            let review = try HandReview(match: boundary == actions.count ? self : rewound(toActionCount: boundary))
            let (handAgreed, handPlays) = review.agreement(forSeat: seat)
            plays += handPlays
            agreed += handAgreed
        }
        let contracts = history.filter { $0.bidder == seat }
        let made = contracts.filter(\.contractMade).count
        return SeatPerformance(plays: plays, playsAgreed: agreed, bids: contracts.count, bidsMade: made)
    }
}
