import CatchFive

/// A bid the bidding exercise lets the learner tap.
public enum TutorialBid: Hashable, Sendable {
    case points(Int)
    case pass
    case nineAndOut
}

public enum ScoreCategory: String, CaseIterable, Hashable, Sendable {
    case high = "High", low = "Low", jack = "Jack", five = "Five", game = "Game"
}

/// Fixed positions for the five lessons. Tests check every answer key against the rules engine,
/// so a rules change can never leave the tutorial teaching something false.
public enum TutorialFixtures {
    // Lesson 1: East (seat 3) deals; the first three cards go to the dealer's left.
    public static let dealer = 3
    public static var firstDealt: Int { (dealer + 1) % 4 }

    // Lesson 2: West bid 2, Partner bid 3, East (dealer) still to call. Fixed key, see the spec note.
    public static let biddingHand = [Card(.spades, .ace), Card(.spades, .king), Card(.spades, .five),
                                     Card(.hearts, .nine), Card(.clubs, .three), Card(.diamonds, .seven)]
    public static let legalBids: Set<TutorialBid> = Set((4...9).map(TutorialBid.points) + [.pass, .nineAndOut])
    public static let preferredBid = TutorialBid.points(4)

    // Lesson 3: won the bid at 4; spades is the suit to name. The refilled hand after discarding.
    public static let trumpAnswer = Suit.spades
    public static let refilledHand = [Card(.spades, .ace), Card(.spades, .king), Card(.spades, .five),
                                      Card(.spades, .eight), Card(.clubs, .queen), Card(.hearts, .two)]

    // Lesson 4a: West led the king of diamonds with spades trump.
    public static let trickLead = Card(.diamonds, .king)
    public static let trickHand = [Card(.diamonds, .nine), Card(.spades, .ace), Card(.clubs, .seven),
                                   Card(.diamonds, .two), Card(.hearts, .queen), Card(.spades, .eight)]
    public static let trickLegalAnswers = [Card(.diamonds, .nine), Card(.diamonds, .two)]

    // Lesson 4b: four cards down; East's small trump takes it.
    public static let fullTrick = [Play(seat: 1, card: Card(.diamonds, .king)), Play(seat: 2, card: Card(.diamonds, .nine)),
                                   Play(seat: 3, card: Card(.spades, .two)), Play(seat: 0, card: Card(.diamonds, .ace))]
    public static let trickWinnerAnswer = 3

    // Lesson 5: captured piles with spades trump; they bid 4; scores before the hand were 10–5.
    public static let usCaptured = [Card(.spades, .ace), Card(.spades, .three), Card(.clubs, .ten), Card(.hearts, .seven),
                                    Card(.diamonds, .seven), Card(.clubs, .nine), Card(.diamonds, .four), Card(.spades, .eight)]
    // The reference build had 6♥ here, which leaves Game with Us (A♠ 4 + 10♣ 10 = 14 against 13);
    // the engine test caught it, so Them hold K♥ instead: 16 against 14.
    public static let themCaptured = [Card(.spades, .five), Card(.spades, .jack), Card(.hearts, .ten), Card(.diamonds, .queen),
                                      Card(.clubs, .two), Card(.hearts, .king), Card(.diamonds, .nine), Card(.clubs, .eight)]
    public static let scoresBefore = [10, 5]
    public static let theirBid = 4
    public static let scoringAnswers: [ScoreCategory: Int] = [.high: 0, .low: 0, .jack: 1, .five: 1, .game: 1]
    public static let scoringExplanations: [ScoreCategory: String] = [
        .high: "A♠ is the highest trump played.",
        .low: "3♠ is the lowest trump played (the 2♠ was never dealt).",
        .jack: "They captured the J♠.",
        .five: "They captured the 5♠.",
        .game: "Your A♠ + 10♣ = 4 + 10 = 14. Their 10♥ + K♥ + Q♦ + J♠ = 10 + 3 + 2 + 1 = 16.",
    ]
}
