import CatchFive

func runComputerMatch() throws {
    var match = try Match(deck: deck.shuffled(), dealer: 3)
    print("CATCH 5 — four computer players, shuffled deck")
    for _ in 0..<10000 {
        if let winner = match.winner {
            print("WINNER: Team \(winner), scores \(match.scores), after \(match.handNumber) hands.")
            return
        }
        if match.hand.phase == .finished {
            print("Hand \(match.handNumber): points \(match.hand.result!.points), running scores \(match.scores)")
            try match.startNextHand(deck: deck.shuffled())
            continue
        }
        guard let seat = match.hand.nextSeat,
              let action = ComputerPlayer.decide(try PlayerView(match: match, seat: seat)) else {
            throw DemoError.noLegalMove
        }
        switch action {
        case .nineAndOut: print("Seat \(seat): 9 and out")
        case let .bid(amount): print("Seat \(seat): \(amount.map { "bid \($0)" } ?? "pass")")
        case let .chooseTrump(suit): print("Seat \(seat): trump is \(suit.rawValue)")
        case let .play(card): print("Seat \(seat): \(label(card))")
        }
        try match.apply(action, seat: seat)
    }
    throw DemoError.matchDidNotFinish
}
