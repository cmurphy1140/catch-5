import Testing
@testable import CatchFive

@Test func mustFollowSuitEvenWithTrump() {
    let club = Card(.clubs, .two)
    let hand = [club, Card(.hearts, .ace)]
    #expect(legalCards(in: hand, led: .clubs) == [club])
    #expect(legalCards(in: hand, led: .spades) == hand)
    #expect(legalCards(in: hand, led: nil) == hand)
}

@Test func trumpBeatsLedAce() throws {
    let plays = [Play(seat: 2, card: Card(.clubs, .ace)),
                 Play(seat: 3, card: Card(.hearts, .two)),
                 Play(seat: 0, card: Card(.clubs, .king)),
                 Play(seat: 1, card: Card(.spades, .ace))]
    #expect(try trickWinner(plays, trump: .hearts) == 3)
    #expect(try trickWinner(plays, trump: .diamonds) == 2)
}

@Test func highestTrumpWins() throws {
    let plays = [Play(seat: 0, card: Card(.clubs, .ace)),
                 Play(seat: 1, card: Card(.hearts, .two)),
                 Play(seat: 2, card: Card(.hearts, .king)),
                 Play(seat: 3, card: Card(.hearts, .five))]
    #expect(try trickWinner(plays, trump: .hearts) == 2)
}

@Test func malformedTricksAreRejected() {
    #expect(throws: RuleError.invalidTrick) { try trickWinner([], trump: .clubs) }
    let duplicate = Array(repeating: Play(seat: 0, card: Card(.clubs, .ace)), count: 4)
    #expect(throws: RuleError.invalidTrick) { try trickWinner(duplicate, trump: .clubs) }
}

@Test func cardValuesForGame() {
    #expect(Rank.allCases.map(\.gameValue) == [0, 0, 0, 0, 0, 0, 0, 0, 10, 1, 2, 3, 4])
}
