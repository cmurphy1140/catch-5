import CatchFive
import Foundation

/// One finished match, recorded once when the winner is decided.
public struct MatchRecord: Codable, Equatable, Sendable {
    public var date: Date
    public var scores: [Int]
    public var winner: Int
    public var hands: Int
    public var difficulty: Difficulty
    public var humanBids: Int
    public var humanBidsMade: Int
    public var humanPlays: Int
    public var humanPlaysAgreed: Int

    public init(date: Date, scores: [Int], winner: Int, hands: Int, difficulty: Difficulty,
                humanBids: Int, humanBidsMade: Int, humanPlays: Int, humanPlaysAgreed: Int) {
        self.date = date
        self.scores = scores
        self.winner = winner
        self.hands = hands
        self.difficulty = difficulty
        self.humanBids = humanBids
        self.humanBidsMade = humanBidsMade
        self.humanPlays = humanPlays
        self.humanPlaysAgreed = humanPlaysAgreed
    }

    public var humanWon: Bool { winner == 0 }
    public var margin: Int { scores[0] - scores[1] }
}

/// Totals across every recorded match.
public struct Statistics: Equatable, Sendable {
    public let matches: Int
    public let wins: Int
    public let averageMargin: Double
    public let contractRate: Double?
    public let agreementRate: Double?

    public init(_ records: [MatchRecord]) {
        matches = records.count
        wins = records.filter(\.humanWon).count
        averageMargin = records.isEmpty ? 0 : Double(records.reduce(0) { $0 + $1.margin }) / Double(records.count)
        let bids = records.reduce(0) { $0 + $1.humanBids }
        contractRate = bids == 0 ? nil : Double(records.reduce(0) { $0 + $1.humanBidsMade }) / Double(bids)
        let plays = records.reduce(0) { $0 + $1.humanPlays }
        agreementRate = plays == 0 ? nil : Double(records.reduce(0) { $0 + $1.humanPlaysAgreed }) / Double(plays)
    }
}

public enum MatchHistoryStore {
    public static func read(from url: URL) throws -> [MatchRecord] {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([MatchRecord].self, from: Data(contentsOf: url))
    }

    public static func write(_ records: [MatchRecord], to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(records).write(to: url, options: .atomic)
    }
}
