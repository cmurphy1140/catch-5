import Foundation

/// A drawable face: a recipe, not an image. `PortraitView` renders it at any size.
public struct Portrait: Codable, Equatable, Hashable, Sendable {
    public enum Skin: String, Codable, CaseIterable, Sendable { case light, tan, brown, deep }
    public enum Hair: String, Codable, CaseIterable, Sendable { case short, bob, curly, bald }
    public enum HairColor: String, Codable, CaseIterable, Sendable { case black, brown, blond, silver, red }
    public enum Feature: String, Codable, CaseIterable, Sendable { case none, glasses, moustache, freckles }
    public enum Hat: String, Codable, CaseIterable, Sendable { case none, beanie, cap, flower }
    public enum Shirt: String, Codable, CaseIterable, Sendable { case plum, olive, teal, rust, navy, mustard }
    /// A passing mood drawn on the face: not part of the recipe, never saved.
    public enum Expression: Sendable { case neutral, thinking, pleased, rueful, triumphant, dismayed }

    public var skin: Skin
    public var hair: Hair
    public var hairColor: HairColor
    public var feature: Feature
    public var hat: Hat
    public var shirt: Shirt

    public init(skin: Skin, hair: Hair, hairColor: HairColor, feature: Feature = .none, hat: Hat = .none, shirt: Shirt) {
        self.skin = skin
        self.hair = hair
        self.hairColor = hairColor
        self.feature = feature
        self.hat = hat
        self.shirt = shirt
    }
}

/// A named player at the table.
public struct Character: Equatable, Sendable {
    public let name: String
    public let portrait: Portrait

    public init(name: String, portrait: Portrait) {
        self.name = name
        self.portrait = portrait
    }
}

/// The fixed cast. Seats 1, 2 and 3 are always Hazel, Otto and Rue; the human picks a face at login.
public enum Cast {
    /// Index 0 is seat 1 (West), 1 is seat 2 (Partner), 2 is seat 3 (East).
    public static let opponents: [Character] = [
        Character(name: "Hazel", portrait: Portrait(skin: .light, hair: .bob, hairColor: .silver, feature: .glasses, shirt: .plum)),
        Character(name: "Otto", portrait: Portrait(skin: .tan, hair: .short, hairColor: .brown, feature: .moustache, hat: .cap, shirt: .olive)),
        Character(name: "Rue", portrait: Portrait(skin: .brown, hair: .curly, hairColor: .red, feature: .freckles, hat: .beanie, shirt: .teal)),
    ]

    /// Faces the human can choose from at login and in Settings.
    public static let playerChoices: [Portrait] = [
        Portrait(skin: .tan, hair: .short, hairColor: .black, shirt: .navy),
        Portrait(skin: .deep, hair: .curly, hairColor: .black, shirt: .mustard),
        Portrait(skin: .light, hair: .bob, hairColor: .blond, hat: .flower, shirt: .rust),
        Portrait(skin: .brown, hair: .bald, hairColor: .black, feature: .glasses, shirt: .teal),
    ]

    public static let defaultPlayerPortrait = playerChoices[0]

    /// Direction words for accessibility and lesson text, indexed by seat.
    public static let seatWords = ["You", "West", "Partner", "East"]

    /// The opponent seated at `seat` (1 to 3), or nil for the human.
    public static func opponent(at seat: Int) -> Character? {
        (1...3).contains(seat) ? opponents[seat - 1] : nil
    }
}
