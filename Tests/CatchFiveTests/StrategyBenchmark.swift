import Testing
@testable import CatchFive

typealias Strategy = (PlayerView) -> PlayerAction?

struct BenchmarkResult {
    var candidateWins = 0
    var baselineWins = 0
    /// Sum over matches of (candidate score − baseline score) at the final settlement.
    var margin = 0
    var matches: Int { candidateWins + baselineWins }
    var candidateWinRate: Double { Double(candidateWins) / Double(matches) }
    var marginPerMatch: Double { Double(margin) / Double(matches) }
}

/// Plays one seeded match with `teamZero` steering seats 0/2 and `teamOne` seats 1/3.
func playSeededMatch(seed: Int, teamZero: Strategy, teamOne: Strategy) throws -> Match {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var random = RepeatableRandom(state: UInt64(seed))
    var match = try Match(deck: deck.shuffled(using: &random), dealer: seed % 4)
    while match.winner == nil {
        if match.hand.phase == .finished {
            try match.startNextHand(deck: deck.shuffled(using: &random))
            continue
        }
        let seat = try #require(match.hand.nextSeat)
        let strategy = seat % 2 == 0 ? teamZero : teamOne
        let action = try #require(strategy(PlayerView(match: match, seat: seat)))
        try match.apply(action, seat: seat)
    }
    return match
}

/// Every seed is played twice with the teams swapped so seat and dealer advantages cancel.
func mirroredBenchmark(seeds: Range<Int>, candidate: @escaping Strategy, baseline: @escaping Strategy) throws -> BenchmarkResult {
    var result = BenchmarkResult()
    for seed in seeds {
        let first = try playSeededMatch(seed: seed, teamZero: candidate, teamOne: baseline)
        if first.winner == 0 { result.candidateWins += 1 } else { result.baselineWins += 1 }
        result.margin += first.scores[0] - first.scores[1]
        let second = try playSeededMatch(seed: seed, teamZero: baseline, teamOne: candidate)
        if second.winner == 1 { result.candidateWins += 1 } else { result.baselineWins += 1 }
        result.margin += second.scores[1] - second.scores[0]
    }
    return result
}

@Test func benchmarkHarnessIsFairWhenBothSidesUseTheSameStrategy() throws {
    let result = try mirroredBenchmark(seeds: 1..<51, candidate: BaselinePlayer.decide, baseline: BaselinePlayer.decide)
    #expect(result.matches == 100)
    #expect(result.candidateWins == result.baselineWins)
    #expect(result.margin == 0)
}

/// The improvement target: the shipped player must clearly beat the frozen PR #2 player.
@Test func computerPlayerBeatsFrozenBaseline() throws {
    let result = try mirroredBenchmark(seeds: 1..<301, candidate: ComputerPlayer.decide, baseline: BaselinePlayer.decide)
    // Measured 0.66 with a +5.5 point margin per match on 2026-09-04; the bar sits well below that.
    #expect(result.candidateWinRate >= 0.58)
    #expect(result.marginPerMatch >= 2)
}
