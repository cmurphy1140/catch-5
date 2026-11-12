import CatchFive
import CryptoKit
import Foundation

public enum HandArchiveError: Error, Equatable {
    case invalidEntry, unsupportedVersion(Int), invalidScope
}

/// One completed replay, with the names and saved date known when it was captured. Recovered hands use
/// current table names; the old action log does not contain historical names or a played timestamp.
public struct ArchivedHand: Codable, Identifiable, Sendable {
    public let version: Int
    public let id: String
    public let dealID: String
    public let savedAt: Date
    public let recovered: Bool
    public let names: [String]
    public let opponents: Settings.Opponents
    public let mode: PlayMode
    public let difficulty: Difficulty
    public let handNumber: Int
    public let bidder: Int
    public let bid: Int
    public let isNineAndOut: Bool
    public let trump: Suit
    public let before: [Int]
    public let after: [Int]
    public let tricksWonBySeat: [Int]
    public let winner: Int?
    public let source: Data

    init(replay: HandReplay, date: Date, names: [String], opponents: Settings.Opponents,
         mode: PlayMode, difficulty: Difficulty, recovered: Bool) throws {
        version = 1
        id = try HandArchiveStore.identity(for: replay.finishedMatch)
        dealID = try HandArchiveStore.dealIdentity(for: replay.finishedMatch)
        savedAt = date
        self.recovered = recovered
        self.names = names
        self.opponents = opponents
        self.mode = mode
        self.difficulty = difficulty
        handNumber = replay.number
        bidder = replay.bidder
        bid = replay.bid
        isNineAndOut = replay.isNineAndOut
        trump = replay.trump
        before = replay.before
        after = replay.after
        tricksWonBySeat = Self.tricks(in: replay)
        winner = replay.winner
        source = try MatchSave.encode(replay.finishedMatch)
        _ = try self.replay()
    }

    /// Validate stored metadata against the ordinary engine replay before any cards are revealed.
    public func replay() throws -> HandReplay {
        guard version == 1 else { throw HandArchiveError.unsupportedVersion(version) }
        guard names.count == 4, before.count == 2, after.count == 2, tricksWonBySeat.count == 4,
              savedAt.timeIntervalSince1970.isFinite else { throw HandArchiveError.invalidEntry }
        let match = try MatchSave.decode(source)
        let replay = try HandReplay(match: match)
        guard id == (try HandArchiveStore.identity(for: match)),
              dealID == (try HandArchiveStore.dealIdentity(for: match)),
              handNumber == replay.number, bidder == replay.bidder, bid == replay.bid,
              isNineAndOut == replay.isNineAndOut, trump == replay.trump,
              before == replay.before, after == replay.after, winner == replay.winner,
              tricksWonBySeat == Self.tricks(in: replay) else { throw HandArchiveError.invalidEntry }
        return replay
    }

    private static func tricks(in replay: HandReplay) -> [Int] {
        replay.finishedMatch.hand.completedTricks.reduce(into: [0, 0, 0, 0]) { $0[$1.winner] += 1 }
    }
}

public struct HandArchiveListing: Sendable {
    public let entries: [ArchivedHand]
    public let unreadableFiles: [String]
    public let hasMore: Bool

    public init(entries: [ArchivedHand] = [], unreadableFiles: [String] = [], hasMore: Bool = false) {
        self.entries = entries
        self.unreadableFiles = unreadableFiles
        self.hasMore = hasMore
    }
}

/// These counts describe saved real completions, not unavailable older aggregate match history.
public struct HandArchiveStatistics: Equatable, Sendable {
    public let hands: Int
    public let soloHands: Int
    public let yourTricks: Int

    public init(_ entries: [ArchivedHand] = []) {
        let unique = Dictionary(entries.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values
        hands = unique.count
        let solo = unique.filter { $0.mode == .solo }
        soloHands = solo.count
        yourTricks = solo.reduce(0) { $0 + $1.tricksWonBySeat[0] }
    }
}

/// A read-only snapshot, safe to validate away from the UI actor. It never opens or changes a player scope.
public struct HandArchiveReadRequest: Sendable {
    let entriesURL: URL
    let scopeID: UUID
    let limit: Int
    let excludingDealID: String?

    public func read() throws -> HandArchiveListing {
        try Task.checkCancellation()
        let urls = try FileManager.default.contentsOfDirectory(at: entriesURL, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        var entries: [ArchivedHand] = []
        var unreadable: [String] = []
        for url in urls {
            try Task.checkCancellation()
            do {
                let entry = try Self.readEntry(url)
                guard url.lastPathComponent == entry.id + ".json" else { throw HandArchiveError.invalidEntry }
                if entry.dealID != excludingDealID { entries.append(entry) }
            } catch is CancellationError { throw CancellationError() }
            catch { unreadable.append(url.lastPathComponent) }
        }
        entries.sort { $0.savedAt == $1.savedAt ? $0.id < $1.id : $0.savedAt > $1.savedAt }
        let count = max(0, limit)
        return HandArchiveListing(entries: Array(entries.prefix(count)), unreadableFiles: unreadable,
                                  hasMore: entries.count > count)
    }

    fileprivate static func readEntry(_ url: URL) throws -> ArchivedHand {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        let entry = try decoder.decode(ArchivedHand.self, from: Data(contentsOf: url))
        _ = try entry.replay()
        return entry
    }
}

/// Atomically written, versioned hand files in the current player's scope. Old scopes and unreadable
/// files are retained; a new player changes only the active marker after the new scope can be created.
public final class HandArchiveStore {
    private struct Scope: Codable {
        let version: Int
        let id: UUID
    }

    public let directory: URL
    private var scope: Scope
    private var markerURL: URL { directory.appendingPathComponent("player-scope.json") }
    private var entriesURL: URL { directory.appendingPathComponent("players", isDirectory: true).appendingPathComponent(scope.id.uuidString, isDirectory: true) }

    public init(directory: URL) throws {
        self.directory = directory
        let marker = directory.appendingPathComponent("player-scope.json")
        if FileManager.default.fileExists(atPath: marker.path) {
            scope = try JSONDecoder().decode(Scope.self, from: Data(contentsOf: marker))
            guard scope.version == 1 else { throw HandArchiveError.invalidScope }
        } else {
            scope = Scope(version: 1, id: UUID())
            try FileManager.default.createDirectory(at: entriesURL, withIntermediateDirectories: true)
            try JSONEncoder().encode(scope).write(to: marker, options: .atomic)
        }
        try FileManager.default.createDirectory(at: entriesURL, withIntermediateDirectories: true)
    }

    public static func identity(for match: Match) throws -> String {
        guard match.hand.phase == .finished else { throw HandReplayError.handNotFinished }
        return digest(try MatchSave.encode(match))
    }

    public static func dealIdentity(for match: Match) throws -> String {
        digest(try MatchSave.encode(match.rewound(toActionCount: match.handStartActionCount)))
    }

    @discardableResult
    public func save(_ match: Match, date: Date, names: [String], opponents: Settings.Opponents,
                     mode: PlayMode, difficulty: Difficulty, recovered: Bool = false) throws -> ArchivedHand {
        let replay = try HandReplay(match: match)
        let entry = try ArchivedHand(replay: replay, date: date, names: names, opponents: opponents,
                                     mode: mode, difficulty: difficulty, recovered: recovered)
        let url = entriesURL.appendingPathComponent(entry.id + ".json")
        if FileManager.default.fileExists(atPath: url.path) {
            // A recapture must not rename or redate the original. A corrupt original is never replaced.
            let original = try HandArchiveReadRequest.readEntry(url)
            guard original.id == entry.id else { throw HandArchiveError.invalidEntry }
            return original
        }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        try encoder.encode(entry).write(to: url, options: .atomic)
        return entry
    }

    var scopeID: UUID { scope.id }

    public func readRequest(limit: Int = 50, excludingDealID: String? = nil) -> HandArchiveReadRequest {
        HandArchiveReadRequest(entriesURL: entriesURL, scopeID: scope.id, limit: limit, excludingDealID: excludingDealID)
    }

    public func entries(limit: Int = 50, excludingDealID: String? = nil) throws -> HandArchiveListing {
        try readRequest(limit: limit, excludingDealID: excludingDealID).read()
    }

    public func beginNewPlayer() throws {
        let next = Scope(version: 1, id: UUID())
        let target = directory.appendingPathComponent("players", isDirectory: true).appendingPathComponent(next.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: target, withIntermediateDirectories: true)
        try JSONEncoder().encode(next).write(to: markerURL, options: .atomic)
        scope = next
    }

    private static func digest(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
