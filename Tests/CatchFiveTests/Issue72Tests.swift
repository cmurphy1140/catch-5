import Testing
@testable import CatchFive

@Test func avoidSurrenderingTheTenWhenFollowingSuit() throws {
    let cards = [
        Card(.spades, .queen),
        Card(.spades, .ten)
    ]
    let trick = [
        Play(seat: 2, card: Card(.spades, .eight)),
        Play(seat: 3, card: Card(.spades, .four)),
        Play(seat: 0, card: Card(.spades, .king))
    ]
    let view = PlayerView(seat: 1, cards: cards, phase: .playing, nextSeat: 1,
                          dealer: 0, highestBid: 3, bidder: 0, trump: .spades, trick: trick)
    
    let action = try #require(ComputerPlayer.decide(view))
    #expect(action == .play(Card(.spades, .queen)))
}
