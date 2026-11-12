import CatchFive

public enum PracticeDeal: String, CaseIterable, Identifiable, Sendable {
    case fresh, trumpRich, mixed
    public var id: String { rawValue }
    public var title: String {
        switch self {
        case .fresh: "Fresh deal"
        case .trumpRich: "Trump-rich hand"
        case .mixed: "Mixed hand"
        }
    }

    /// What the choice gives you, in a line under its name (D181).
    public var detail: String {
        switch self {
        case .fresh: "Shuffled, a new hand every time."
        case .trumpRich: "Six hearts, the five among them."
        case .mixed: "A card or two of every suit."
        }
    }

    /// Curated deals put their six sample cards at seat 0 when dealer 3 deals in packets of three.
    public func deck() -> [Card] {
        let all = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
        guard self != .fresh else { return all.shuffled() }
        let sample: [Card] = self == .trumpRich
            ? [.init(.hearts, .ace), .init(.hearts, .king), .init(.hearts, .queen),
               .init(.hearts, .jack), .init(.hearts, .ten), .init(.hearts, .five)]
            : [.init(.clubs, .ace), .init(.diamonds, .five), .init(.hearts, .king),
               .init(.spades, .jack), .init(.clubs, .three), .init(.diamonds, .eight)]
        var remaining = all.filter { !sample.contains($0) }
        var deck = Array(sample.prefix(3))
        deck += remaining.prefix(9)
        remaining.removeFirst(9)
        deck += sample.suffix(3)
        deck += remaining
        return deck
    }
}

public struct PracticeConfiguration: Equatable, Sendable {
    public var left: Difficulty
    public var partner: Difficulty
    public var right: Difficulty
    public var deal: PracticeDeal

    public init(left: Difficulty = .standard, partner: Difficulty = .standard,
                right: Difficulty = .standard, deal: PracticeDeal = .fresh) {
        self.left = left
        self.partner = partner
        self.right = right
        self.deal = deal
    }

    public func difficulty(forSeat seat: Int) -> Difficulty {
        switch seat {
        case 1: left
        case 2: partner
        case 3: right
        default: .standard
        }
    }
}
