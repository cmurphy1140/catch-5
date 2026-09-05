import CatchFive
import Foundation

/// One finished match, recorded once when the winner is decided. Dates are stored to the second.
/// Fields added later must have defaults here so older history files keep loading.
public struct MatchRecord: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var date: Date
    public var scores: [Int]
    public var winner: Int
    public var hands: Int
    public var difficulty: Difficulty
    public var humanBids: Int
    public var humanBidsMade: Int
    public var humanPlays: Int
    public var humanPlaysAgreed: Int

    public init(id: UUID = UUID(), date: Date, scores: [Int], winner: Int, hands: Int, difficulty: Difficulty,
                humanBids: Int, humanBidsMade: Int, humanPlays: Int, humanPlaysAgreed: Int) {
        self.id = id
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        date = try container.decode(Date.self, forKey: .date)
        scores = try container.decode([Int].self, forKey: .scores)
        guard scores.count == 2 else {
            throw DecodingError.dataCorruptedError(forKey: .scores, in: container, debugDescription: "two team scores expected")
        }
        winner = try container.decode(Int.self, forKey: .winner)
        hands = try container.decode(Int.self, forKey: .hands)
        difficulty = try container.decodeIfPresent(Difficulty.self, forKey: .difficulty) ?? .standard
        humanBids = try container.decodeIfPresent(Int.self, forKey: .humanBids) ?? 0
        humanBidsMade = try container.decodeIfPresent(Int.self, forKey: .humanBidsMade) ?? 0
        humanPlays = try container.decodeIfPresent(Int.self, forKey: .humanPlays) ?? 0
        humanPlaysAgreed = try container.decodeIfPresent(Int.self, forKey: .humanPlaysAgreed) ?? 0
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
    /// Reads the history, or sets a file that cannot be decoded aside as `history-corrupt.json`
    /// next to it and returns an empty list, so play continues and nothing is overwritten.
    public static func readSettingAsideCorruption(at url: URL) -> [MatchRecord] {
        guard FileManager.default.fileExists(atPath: url.path) else { return [] }
        do { return try read(from: url) } catch {
            let aside = url.deletingLastPathComponent().appendingPathComponent("history-corrupt.json")
            try? FileManager.default.removeItem(at: aside)
            try? FileManager.default.moveItem(at: url, to: aside)
            return []
        }
    }

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
