import CatchFive

// This is a repeatable diagnostic demonstration, not the computer-player strategy.
let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }

func label(_ card: Card) -> String {
    let rank: String
    switch card.rank {
    case .jack: rank = "J"
    case .queen: rank = "Q"
    case .king: rank = "K"
    case .ace: rank = "A"
    default: rank = String(card.rank.rawValue)
    }
    return "\(rank) of \(card.suit.rawValue)"
}

func owner(_ team: Int?) -> String {
    team.map { "Team \($0)" } ?? "out of play"
}

func deckForHand(_ number: Int) -> [Card] {
    let rotation = (number * 7) % 52
    return Array(deck[rotation...]) + Array(deck[..<rotation])
}

func runHand(in match: inout Match) throws {
    let number = match.handNumber
    let dealer = match.hand.auction.dealer
    let bidder = (dealer + 1) % 4
    print("\nHAND \(number) | Dealer: Seat \(dealer)")
    try match.bid(seat: bidder, amount: 2)
    for offset in 1...3 { try match.bid(seat: (bidder + offset) % 4, amount: nil) }
    let trump = Suit.allCases[number % 4]
    try match.chooseTrump(seat: bidder, suit: trump)
    print("Seat \(bidder) bids 2; others pass. Trump: \(trump.rawValue).")
    print("Refill complete: \(match.hand.stock.count) undealt, \(match.hand.discarded.count) discarded.")
    while let seat = match.hand.nextSeat {
        guard let card = match.hand.legalMoves(seat: seat).first else { throw DemoError.noLegalMove }
        try match.play(seat: seat, card: card)
        if CommandLine.arguments.contains("--save-roundtrip"), number == 1,
           match.hand.completedTricks.isEmpty, match.hand.currentTrick.count == 3 {
            let data = try MatchSave.encode(match)
            match = try MatchSave.decode(data)
            print("SAVE/RESUME: restored three cards on the table; Seat \(match.hand.nextSeat!) acts next.")
        }
        if match.hand.currentTrick.isEmpty, let trick = match.hand.completedTricks.last {
            let plays = trick.plays.map { "Seat \($0.seat): \(label($0.card))" }.joined(separator: " | ")
            print("Trick \(match.hand.completedTricks.count): \(plays) -> Seat \(trick.winner)")
        }
    }
}

enum DemoError: Error { case noLegalMove, incompleteHand, matchDidNotFinish }

func runMatch() throws {
    var match = try Match(deck: deckForHand(1), dealer: 3)
    print("CATCH 5 — automated text demonstration")
    print("Team 0: seats 0/2. Team 1: seats 1/3. First to 25.")
    for number in 1...200 {
        if number > 1 { try match.startNextHand(deck: deckForHand(number)) }
        try runHand(in: &match)
        guard let result = match.hand.result else { throw DemoError.incompleteHand }
        print("High: \(owner(result.highTeam)); Low: \(owner(result.lowTeam)); Jack: \(owner(result.jackTeam)); Five: \(owner(result.fiveTeam))")
        print("Game values: \(result.gameValues), awarded to Team \(result.gameTeam). Hand points: \(result.points)")
        print("Running score — Team 0: \(match.scores[0]), Team 1: \(match.scores[1])")
        if let winner = match.winner {
            print("\nWINNER: Team \(winner) after \(number) hands.")
            return
        }
    }
    throw DemoError.matchDidNotFinish
}

try runMatch()
