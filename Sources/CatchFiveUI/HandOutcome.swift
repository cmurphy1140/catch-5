import CatchFive

/// The finished hand in the order a player wants it: did the contract make, what did that do to the
/// score, what did the defenders get, and any rule that decided a close case. Built from numbers the
/// engine already produced, so it can be tested without playing a hand.
struct HandOutcome: Equatable {
    let headline: String
    /// "Connor + Otto bid 4 · captured 6 · score 2 → 8"
    let bidderLine: String
    /// "Hazel + Rue captured 3 · score 5 → 8"
    let defenderLine: String
    /// Rules that decided something on this hand, in the words a player would use.
    let notes: [String]

    init(bidderTeam: Int, bid: Int, isNineAndOut: Bool, points: [Int], gameValues: [Int],
         fiveTeam: Int?, jackTeam: Int?, before: [Int], after: [Int], names: [String]) {
        let defenders = 1 - bidderTeam
        func team(_ t: Int) -> String { "\(names[t]) + \(names[t + 2])" }
        let captured = points[bidderTeam]

        if isNineAndOut {
            let made = captured == 9
            headline = made ? "9 and out made" : "9 and out failed"
            bidderLine = "\(team(bidderTeam)) bid 9 and out · captured \(made ? "all 9" : "\(captured) of 9") · match \(made ? "won" : "lost")"
            defenderLine = "\(team(defenders)) captured \(points[defenders]) · scores unchanged"
        } else {
            headline = captured >= bid ? "Contract made" : "Contract set"
            bidderLine = "\(team(bidderTeam)) bid \(bid) · captured \(captured) · score \(before[bidderTeam]) → \(after[bidderTeam])"
            defenderLine = "\(team(defenders)) captured \(points[defenders]) · score \(before[defenders]) → \(after[defenders])"
        }

        var notes: [String] = []
        if gameValues[0] == gameValues[1] {
            notes.append("Game tied \(gameValues[0])–\(gameValues[1]): the tie goes to the bidding team.")
        }
        if fiveTeam == nil { notes.append("The trump Five was not dealt, so its 5 points were out of play.") }
        if jackTeam == nil { notes.append("The trump Jack was not dealt, so its point was out of play.") }
        if !isNineAndOut, after[0] >= 25, after[1] >= 25 {
            notes.append("Both teams reached 25: the bidding team wins the match.")
        }
        self.notes = notes
    }

    /// The engine's record of a hand, with the scores as they stood before it.
    init(summary: HandSummary, before: [Int], names: [String]) {
        self.init(bidderTeam: summary.bidder % 2, bid: summary.bid, isNineAndOut: summary.isNineAndOut,
                  points: summary.result.points, gameValues: summary.result.gameValues,
                  fiveTeam: summary.result.fiveTeam, jackTeam: summary.result.jackTeam,
                  before: before, after: summary.scores, names: names)
    }
}
