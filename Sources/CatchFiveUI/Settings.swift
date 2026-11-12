import CatchFive
import Foundation

/// Player preferences. They live outside the rules engine; the table and view model read them.
public struct Settings: Codable, Equatable, Sendable {
    public enum PlaySpeed: String, Codable, CaseIterable, Sendable {
        case relaxed, normal, quick
    }

    public var playSpeed: PlaySpeed
    /// Seat 0 is the human; all four default to the family table (T09).
    public var seatNames: [String]
    public var haptics: Bool
    public var difficulty: Difficulty
    /// The tutorial opens by itself until the player has dismissed it once.
    public var hasSeenRules: Bool
    /// Tutorial lessons (0 to 4) whose exercise has been solved.
    public var completedLessons: Set<Int>
    /// Nil until the login screen has been completed once.
    public var playerName: String?
    /// The face the human chose at login.
    public var playerPortrait: Portrait
    /// Hints and guided play (spec R14). Off is normal mode: a clean table, no coaching, the same rules.
    public var beginnerMode: Bool
    /// The tip the card between the home screen and the table shows next, so each visit carries on where
    /// the last one stopped (D67). Any value is read modulo the number of tips.
    public var nextTip: Int
    /// The table has shown, once, how the trump tally and the out-of-trump marks are tapped (N61).
    public var hasSeenTallyDemo: Bool
    /// How the play table is arranged (D113): a trial switch between today's table and two reworks, until one is chosen.
    public var tableArrangement: TableArrangement = .rail

    /// The table's colours (D118): the cloth and the wood round it, changed from Settings at any time.
    public var tableColours: TableColours = .charcoal

    public enum TableColours: String, Codable, CaseIterable, Sendable {
        /// Charcoal or green cloth on oak, the two the table offers (D158). Royal and casino are no longer offered;
        /// they stay so an old save still reads, and a save that holds one opens on charcoal.
        case charcoal, green, royal, casino
        /// The cloths the settings page offers.
        public static let offered: [TableColours] = [.charcoal, .green]
        /// The two paler woods take dark ink where the oak takes ivory.
        public var woodIsLight: Bool { self == .royal || self == .casino }
    }

    public enum TableArrangement: String, Codable, CaseIterable, Sendable {
        /// Today's table. `around`: the field fills the table, the side seats on it. `rail`: the three other seats in a
        /// row above the field, which holds only the trick.
        case classic, around, rail
    }

    /// Who sits in the three other seats (D160): the new cast, or the family table it replaced, still offered in Settings.
    public enum Opponents: String, Codable, CaseIterable, Sendable {
        case friends, family
        /// All four seat names; seat 0 is the same either way.
        public var names: [String] { self == .friends ? Settings.defaultSeatNames : Settings.familySeatNames }
        /// "Marcus, Meg, Monica".
        public var label: String { names[1...3].joined(separator: ", ") }
    }
    public var opponents: Opponents = .friends

    /// The four who share the phone in pass and play (D180), in seat order; nil until the new-game sheet has been
    /// used for one, when seat names are read as before. Kept apart from `seatNames`, so the computer players keep theirs.
    public var passAndPlayNames: [String]?

    /// Four names for pass and play from what was typed: trimmed, and a blank one takes its fallback.
    public static func passAndPlayNames(typed: [String], fallback: [String]) -> [String] {
        (0..<4).map { seat in
            let name = typed.indices.contains(seat) ? typed[seat].trimmingCharacters(in: .whitespacesAndNewlines) : ""
            return name.isEmpty ? (fallback.indices.contains(seat) ? fallback[seat] : defaultSeatNames[seat]) : name
        }
    }

    /// The names at the table for a mode: pass and play has its own four once they have been set (D180); before that,
    /// and in solo, the seat names, with seat 0 dropping the phone holder's own name in pass and play.
    public func names(passAndPlay: Bool) -> [String] {
        guard passAndPlay else { return seatNames }
        if let passAndPlayNames { return passAndPlayNames }
        var names = seatNames
        if names[0] == playerName { names[0] = Settings.defaultSeatNames[0] }
        return names
    }

    public static let defaultSeatNames = ["Cheryl", "Marcus", "Meg", "Monica"]
    /// The family table (T09), the default until D160.
    public static let familySeatNames = ["Cheryl", "JC", "Doug", "Diane"]

    /// Seats the chosen three; the player's own seat is left alone.
    public mutating func seat(_ chosen: Opponents) {
        opponents = chosen
        for seat in 1...3 { seatNames[seat] = chosen.names[seat] }
    }
    /// The defaults before the cast existed; files still carrying them migrate on load.
    public static let legacySeatNames = ["You", "West", "Partner", "East"]
    /// The cast's names before the family table (T09); files still carrying them migrate on load.
    public static let oldCastSeatNames = ["Hazel", "Otto", "Rue"]

    public var hasSignedIn: Bool { playerName != nil }

    /// The one place the player's name is written: trimmed, and mirrored into seat 0 unless another seat
    /// already carries it (Connor signing in must not make two Connors). Blank input is ignored.
    public mutating func setPlayerName(_ name: String) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let previous = playerName
        playerName = trimmed
        if !seatNames[1...3].contains(trimmed) {
            seatNames[0] = trimmed
        } else if let previous, seatNames[0] == previous, !seatNames[1...3].contains(previous) {
            // Seat 0 was mirroring an earlier (or half-typed) name; it goes back to the family default.
            seatNames[0] = Settings.defaultSeatNames[0]
        }
    }

    /// A name typed on a seat's tag at the table (D93): seat 0 goes through `setPlayerName`, the others are trimmed
    /// and written as they are. Blank input keeps the old name.
    public mutating func renameSeat(_ seat: Int, to name: String, passAndPlay: Bool = false) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, seatNames.indices.contains(seat) else { return }
        // In pass and play the tag renames that game's own four, once they exist (D180).
        if passAndPlay, var names = passAndPlayNames { names[seat] = trimmed; passAndPlayNames = names; return }
        if seat == 0 { setPlayerName(trimmed) } else { seatNames[seat] = trimmed }
    }

    public init(playSpeed: PlaySpeed = .relaxed, seatNames: [String] = Settings.defaultSeatNames,
                haptics: Bool = true, difficulty: Difficulty = .standard, hasSeenRules: Bool = false,
                completedLessons: Set<Int> = [], playerName: String? = nil,
                playerPortrait: Portrait = Cast.defaultPlayerPortrait, beginnerMode: Bool = true, nextTip: Int = 0,
                hasSeenTallyDemo: Bool = false) {
        self.playSpeed = playSpeed
        self.seatNames = seatNames
        self.haptics = haptics
        self.difficulty = difficulty
        self.hasSeenRules = hasSeenRules
        self.completedLessons = completedLessons
        self.playerName = playerName
        self.playerPortrait = playerPortrait
        self.beginnerMode = beginnerMode
        self.nextTip = nextTip
        self.hasSeenTallyDemo = hasSeenTallyDemo
    }

    // Missing keys fall back to defaults so an older settings file keeps loading.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        // A value this build does not recognise (a newer build's enum case) falls back to its default rather
        // than throwing the whole file away, which would sign the player out.
        playSpeed = (try? container.decodeIfPresent(PlaySpeed.self, forKey: .playSpeed)) ?? nil ?? .relaxed
        haptics = (try? container.decodeIfPresent(Bool.self, forKey: .haptics)) ?? nil ?? true
        difficulty = (try? container.decodeIfPresent(Difficulty.self, forKey: .difficulty)) ?? nil ?? .standard
        hasSeenRules = (try? container.decodeIfPresent(Bool.self, forKey: .hasSeenRules)) ?? nil ?? false
        completedLessons = (try? container.decodeIfPresent(Set<Int>.self, forKey: .completedLessons)) ?? nil ?? []
        playerName = (try? container.decodeIfPresent(String.self, forKey: .playerName)) ?? nil
        playerPortrait = (try? container.decodeIfPresent(Portrait.self, forKey: .playerPortrait)) ?? nil ?? Cast.defaultPlayerPortrait
        // A file from before the setting existed keeps the guidance it always had.
        beginnerMode = (try? container.decodeIfPresent(Bool.self, forKey: .beginnerMode)) ?? nil ?? true
        nextTip = (try? container.decodeIfPresent(Int.self, forKey: .nextTip)) ?? nil ?? 0
        hasSeenTallyDemo = (try? container.decodeIfPresent(Bool.self, forKey: .hasSeenTallyDemo)) ?? nil ?? false
        let cloth = (try? container.decodeIfPresent(TableColours.self, forKey: .tableColours)) ?? nil ?? .charcoal
        tableColours = TableColours.offered.contains(cloth) ? cloth : .charcoal
        // One table (D158): the seats in a row across the top. A save from the trial of three opens on it too.
        tableArrangement = .rail
        // Four names or none: a damaged list is dropped, and pass and play reads the seat names as it used to.
        passAndPlayNames = ((try? container.decodeIfPresent([String].self, forKey: .passAndPlayNames)) ?? nil).flatMap { $0.count == 4 ? $0 : nil }
        let decoded = (try? container.decodeIfPresent([String].self, forKey: .seatNames)) ?? nil ?? Settings.defaultSeatNames
        // A short or long list is damaged: it takes the defaults before anything indexes into it.
        var names = decoded.count == 4 ? decoded : Settings.defaultSeatNames
        // The man across the table was renamed (D159); a save still carrying his old default takes the new one.
        if names[2] == "Connor" { names[2] = Settings.familySeatNames[2] }
        // Only a file from before the cast (no player name yet) still carries the direction defaults by
        // accident; after sign-in a typed "West" is a choice and stays.
        let migrated = playerName == nil ? Settings.migrated(names) : names
        seatNames = migrated
        // A file saved with the old cast in seats 1 to 3 (any order) takes the family table; seat 0 keeps the
        // player's own name unless a family seat already carries it. Names typed by hand never match and stay.
        if Set(seatNames[1...3]) == Set(Settings.oldCastSeatNames) {
            let own = seatNames[0]
            seatNames = Settings.defaultSeatNames
            if own == playerName, !seatNames[1...3].contains(own) { seatNames[0] = own }
        }
        // A save from before the new cast (D160) that still seats the family as it was dealt takes the new three;
        // once the choice has been saved it is the player's, and names typed by hand never match and stay.
        if let saved = (try? container.decodeIfPresent(Opponents.self, forKey: .opponents)) ?? nil {
            opponents = saved
        } else if Array(seatNames[1...3]) == Array(Settings.familySeatNames[1...3]) {
            seat(.friends)
        }
    }

    /// Seats 1 to 3 that still carry the old direction names take the cast's names; custom names are kept.
    static func migrated(_ names: [String]) -> [String] {
        var result = names
        for seat in 1...3 where names[seat] == legacySeatNames[seat] {
            result[seat] = defaultSeatNames[seat]
        }
        return result
    }

    /// How long a finished hand stays on the table, winner ringed, before it is collected: one beat,
    /// `Theme.Motion.botBeat`, so every hand can be read. The saved pace no longer changes it (T11).
    public var trickHold: Duration { Theme.Motion.botBeat }

    /// Pause before a computer acts: the same single beat for leads and follows (T11).
    public func delay(leadingTrick: Bool) -> Duration { Theme.Motion.botBeat }
}

public enum SettingsStore {
    public static func read(from url: URL) throws -> Settings {
        try JSONDecoder().decode(Settings.self, from: Data(contentsOf: url))
    }

    public static func write(_ settings: Settings, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .prettyPrinted]
        try encoder.encode(settings).write(to: url, options: .atomic)
    }
}
