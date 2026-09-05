import Foundation

/// Player preferences. They live outside the rules engine; the table and view model read them.
public struct Settings: Codable, Equatable, Sendable {
    public enum PlaySpeed: String, Codable, CaseIterable, Sendable {
        case relaxed, normal, quick
    }

    public var playSpeed: PlaySpeed
    /// Seat 0 is the human; the others are West, Partner and East by default.
    public var seatNames: [String]
    public var haptics: Bool

    public static let defaultSeatNames = ["You", "West", "Partner", "East"]

    public init(playSpeed: PlaySpeed = .normal, seatNames: [String] = Settings.defaultSeatNames, haptics: Bool = true) {
        self.playSpeed = playSpeed
        self.seatNames = seatNames
        self.haptics = haptics
    }

    // Missing keys fall back to defaults so an older settings file keeps loading.
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        playSpeed = try container.decodeIfPresent(PlaySpeed.self, forKey: .playSpeed) ?? .normal
        let names = try container.decodeIfPresent([String].self, forKey: .seatNames) ?? Settings.defaultSeatNames
        seatNames = names.count == 4 ? names : Settings.defaultSeatNames
        haptics = try container.decodeIfPresent(Bool.self, forKey: .haptics) ?? true
    }

    /// Pause before a computer acts: longer before a lead so the last trick can be read.
    public func delay(leadingTrick: Bool) -> Duration {
        switch playSpeed {
        case .relaxed: leadingTrick ? .milliseconds(1800) : .milliseconds(1000)
        case .normal: leadingTrick ? .milliseconds(1200) : .milliseconds(700)
        case .quick: leadingTrick ? .milliseconds(500) : .milliseconds(300)
        }
    }
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
