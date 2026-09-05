public struct HandScore: Equatable, Sendable {
    public let points: [Int]
    public let gameValues: [Int]
    public let highTeam: Int?
    public let lowTeam: Int?
    public let jackTeam: Int?
    public let fiveTeam: Int?
    public let gameTeam: Int
}

public struct Settlement: Equatable, Sendable {
    public let scores: [Int]
    public let winner: Int?
}

/// Captured cards grouped by partnership. Undealt cards must not be included.
public func scoreHand(captured: [[Card]], trump: Suit, bidder: Int) throws -> HandScore {
    guard captured.count == 2, (0..<2).contains(bidder) else { throw RuleError.invalidScoring }
    let cards = captured.flatMap { $0 }
    guard Set(cards).count == cards.count else { throw RuleError.invalidScoring }
    let trumps = cards.filter { $0.suit == trump }
    let high = trumps.max { $0.rank.rawValue < $1.rank.rawValue }
    let low = trumps.min { $0.rank.rawValue < $1.rank.rawValue }
    func owner(of card: Card?) -> Int? {
        guard let card else { return nil }
        return captured.firstIndex { $0.contains(card) }
    }
    let highTeam = owner(of: high)
    let lowTeam = owner(of: low)
    let jackTeam = owner(of: Card(trump, .jack))
    let fiveTeam = owner(of: Card(trump, .five))
    let values = captured.map { $0.reduce(0) { $0 + $1.rank.gameValue } }
    let gameTeam = values[0] == values[1] ? bidder : (values[0] > values[1] ? 0 : 1)
    var points = [0, 0]
    for team in [highTeam, lowTeam, jackTeam].compactMap({ $0 }) { points[team] += 1 }
    if let fiveTeam { points[fiveTeam] += 5 }
    points[gameTeam] += 1
    return HandScore(points: points, gameValues: values, highTeam: highTeam,
                     lowTeam: lowTeam, jackTeam: jackTeam, fiveTeam: fiveTeam, gameTeam: gameTeam)
}

public func settle(scores: [Int], points: [Int], bidder: Int, bid: Bid) throws -> Settlement {
    guard scores.count == 2, points.count == 2, (0..<2).contains(bidder),
          points.allSatisfy({ (0...9).contains($0) }), points.reduce(0, +) <= 9 else {
        throw RuleError.invalidScoring
    }
    if bid == .nineAndOut {
        guard scores[bidder] >= 0 else { throw RuleError.forbiddenNineAndOut }
        // Match ends immediately; retain pre-hand scores rather than invent a special numeric bonus.
        return Settlement(scores: scores, winner: points[bidder] == 9 ? bidder : 1 - bidder)
    }
    guard case let .points(amount) = bid, (2...9).contains(amount) else { throw RuleError.invalidBid }
    var updated = scores
    updated[bidder] += points[bidder] >= amount ? points[bidder] : -amount
    updated[1 - bidder] += points[1 - bidder]
    let winner = updated[bidder] >= 25 ? bidder : (updated[1 - bidder] >= 25 ? 1 - bidder : nil)
    return Settlement(scores: updated, winner: winner)
}
