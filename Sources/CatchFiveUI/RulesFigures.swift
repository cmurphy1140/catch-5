import CatchFive

/// The numbers the rules sheet draws: point tiles, the Game ledger, the bid ladder and two example
/// tricks. A test checks each against the engine, so a figure can never show a rule the game does not play.
enum RulesFigures {
    struct PointTile: Equatable {
        let name: String
        let points: Int
        let meaning: String
    }

    static let pointTiles: [PointTile] = [
        PointTile(name: "High", points: 1, meaning: "The highest trump that was actually played, not necessarily the ace."),
        PointTile(name: "Low", points: 1, meaning: "The lowest trump that was actually played, not necessarily the two."),
        PointTile(name: "Jack", points: 1, meaning: "The jack of trumps, to whoever captures it. No jack dealt, no point."),
        PointTile(name: "Five", points: 5, meaning: "The five of trumps, worth five on its own. No five dealt, no points."),
        PointTile(name: "Game", points: 1, meaning: "The team whose captured cards add up to more, across every suit. A tie goes to the bidders."),
    ]

    static let gameValues: [(rank: Rank, value: Int)] = [(.ten, 10), (.ace, 4), (.king, 3), (.queen, 2), (.jack, 1)]

    static let bidLadder = Array(HouseRules.bidRange)
    static let matchTarget = HouseRules.matchTarget
    /// All nine, as the sum of the tiles above; the test checks it against the engine's count.
    static var nineAndOutPoints: Int { pointTiles.map(\.points).reduce(0, +) }

    /// Both example tricks: hearts led, spades trump. Seat 1 leads.
    static let trump = Suit.spades
    static let followedTrick = [
        Play(seat: 1, card: Card(.hearts, .nine)),
        Play(seat: 2, card: Card(.hearts, .king)),
        Play(seat: 3, card: Card(.hearts, .four)),
        Play(seat: 0, card: Card(.clubs, .two)),
    ]
    static let followedWinner = 2
    static let trumpedTrick = [
        Play(seat: 1, card: Card(.hearts, .nine)),
        Play(seat: 2, card: Card(.hearts, .king)),
        Play(seat: 3, card: Card(.spades, .four)),
        Play(seat: 0, card: Card(.clubs, .two)),
    ]
    static let trumpedWinner = 3

    /// The trick caption, built from the drawn cards so it can never disagree with the figure.
    static func caption(trumped: Bool) -> String {
        let plays = trumped ? trumpedTrick : followedTrick
        let winner = trumped ? trumpedWinner : followedWinner
        guard let led = plays.first?.card.suit,
              let taker = plays.first(where: { $0.seat == winner })?.card,
              let offSuit = plays.first(where: { $0.card.suit != led && $0.card.suit != trump })?.card else { return "" }
        let highestLed = plays.filter { $0.card.suit == led }.max { $0.card.rank.rawValue < $1.card.rank.rawValue }?.card
        if trumped, let highestLed {
            return "\(trump.rawValue.capitalized) are trump: the \(taker.name) takes it, even though the \(highestLed.name) is higher."
        }
        return "\(led.rawValue.capitalized) were led: the \(taker.name) takes it. The \(offSuit.name) could not follow and cannot win."
    }
}
