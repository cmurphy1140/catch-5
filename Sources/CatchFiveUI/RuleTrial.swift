import CatchFive

/// A rule you can try: a small real position built with the engine, a prompt, the actions on offer,
/// and the engine's own verdict on whatever the reader tries. Nothing here is a second copy of the
/// rules; a refusal is the engine's refusal and an acceptance plays the position out through it.
struct RuleTrial {
    enum Kind: CaseIterable { case followSuit, dealerMatch, nineAndOutBelowZero }

    enum Outcome: Equatable {
        case refused(String)
        case accepted(String)
    }

    let kind: Kind
    let prompt: String
    private let start: Match
    private(set) var match: Match
    /// The last verdict, for the panel to show.
    private(set) var outcome: Outcome?

    private static let names = Settings.defaultSeatNames

    static func make(_ kind: Kind) -> RuleTrial {
        switch kind {
        case .followSuit:
            return RuleTrial(kind: kind, prompt: "Spades are trump, \(names[1]) led a heart and the others followed. Tap any card to see whether the engine allows it.",
                             start: followSuitPosition())
        case .dealerMatch:
            return RuleTrial(kind: kind, prompt: "You are the dealer and \(names[1]) bid 3. Try a bid below, at, or above it, or pass.",
                             start: dealerMatchPosition())
        case .nineAndOutBelowZero:
            return RuleTrial(kind: kind, prompt: "Last hand your bid of 9 failed and your team sits at −9. Try bidding 9 and out.",
                             start: nineAndOutBelowZeroPosition())
        }
    }

    private init(kind: Kind, prompt: String, start: Match) {
        self.kind = kind
        self.prompt = prompt
        self.start = start
        self.match = start
    }

    /// Your cards, for the trials where you play one.
    var offeredCards: [Card] { kind == .followSuit ? match.hand.hands[0] : [] }

    /// The auction choices on offer, for the trials where you bid.
    var offeredActions: [PlayerAction] {
        switch kind {
        case .followSuit: return []
        case .dealerMatch: return [.bid(nil), .bid(2), .bid(3), .bid(4)]
        case .nineAndOutBelowZero: return [.bid(nil), .bid(2), .nineAndOut]
        }
    }

    mutating func reset() {
        match = start
        outcome = nil
    }

    /// The engine judges the action from seat 0. Refusals leave the position alone; an acceptance is
    /// followed through so the reader sees what it led to.
    @discardableResult
    mutating func attempt(_ action: PlayerAction) -> Outcome {
        let led = match.hand.currentTrick.first?.card.suit
        var trial = match
        do {
            try trial.apply(action, seat: 0)
        } catch HandError.mustFollowSuit {
            outcome = .refused(led.map { "Follow \($0.rawValue); you still have \($0.rawValue)." } ?? GameModel.message(for: HandError.mustFollowSuit))
            return outcome!
        } catch {
            outcome = .refused(GameModel.message(for: error))
            return outcome!
        }
        match = trial
        outcome = .accepted(followThrough(after: action))
        return outcome!
    }

    /// Plays the computers' replies with the standard strategy and says what happened.
    private mutating func followThrough(after action: PlayerAction) -> String {
        switch kind {
        case .followSuit:
            while let seat = match.hand.nextSeat, seat != 0, !match.hand.currentTrick.isEmpty {
                guard let view = try? PlayerView(match: match, seat: seat),
                      let reply = ComputerPlayer.decide(view, difficulty: .standard),
                      (try? match.apply(reply, seat: seat)) != nil else { break }
            }
            guard let trick = match.hand.completedTricks.last,
                  let winning = trick.plays.first(where: { $0.seat == trick.winner }) else { return "Accepted." }
            let who = trick.winner == 0 ? "You take" : "\(Self.names[trick.winner]) takes"
            return "Accepted. \(who) the trick with the \(winning.card.name)."
        case .dealerMatch:
            switch action {
            case .bid(nil): return "Passed. \(Self.names[1]) wins the auction with 3 and names trump."
            case .bid(3): return "Accepted: as dealer you may match the high bid. You win the auction with 3 and name trump."
            case let .bid(amount?): return "Accepted: \(amount) beats \(Self.names[1])'s 3. You win the auction and name trump."
            default: return "Accepted."
            }
        case .nineAndOutBelowZero:
            switch action {
            case .bid(nil): return "Passed. Everyone passed, so as dealer you must still bid at least 2."
            case let .bid(amount?): return "Accepted: a normal bid of \(amount) is allowed at any score."
            default: return "Accepted."
            }
        }
    }

    // MARK: Positions

    /// Dealer 3 deals seats 0, 1, 2, 3 three cards each, twice; the stock is what remains, in order.
    private static func deck(seat0: [Card], seat1: [Card], seat2: [Card], seat3: [Card], stock: [Card]) -> [Card] {
        precondition([seat0, seat1, seat2, seat3].allSatisfy { $0.count == 6 })
        var deck: [Card] = []
        for round in 0..<2 {
            for hand in [seat0, seat1, seat2, seat3] { deck += hand[round * 3..<round * 3 + 3] }
        }
        deck += stock
        let all = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
        deck += all.filter { !deck.contains($0) }
        return deck
    }

    /// Seat 1 wins the auction, names spades, and leads a heart. After the refill you hold two spades,
    /// two hearts and two clubs.
    private static func followSuitPosition() -> Match {
        let deck = deck(
            seat0: [Card(.spades, .king), Card(.spades, .seven), Card(.diamonds, .three), Card(.diamonds, .four), Card(.diamonds, .six), Card(.diamonds, .eight)],
            seat1: [Card(.spades, .queen), Card(.spades, .nine), Card(.spades, .four), Card(.diamonds, .nine), Card(.diamonds, .ten), Card(.diamonds, .jack)],
            seat2: [Card(.spades, .ten), Card(.spades, .three), Card(.spades, .two), Card(.clubs, .nine), Card(.clubs, .ten), Card(.clubs, .jack)],
            seat3: [Card(.spades, .ace), Card(.spades, .six), Card(.spades, .five), Card(.diamonds, .queen), Card(.diamonds, .king), Card(.diamonds, .ace)],
            // Refill order after trump is seats 0, 1, 2, 3: you draw four, seat 1 three, seat 2 three, seat 3 three.
            stock: [Card(.hearts, .king), Card(.hearts, .five), Card(.clubs, .two), Card(.clubs, .seven),
                    Card(.hearts, .nine), Card(.hearts, .queen), Card(.clubs, .ace),
                    Card(.hearts, .two), Card(.hearts, .three), Card(.clubs, .three),
                    Card(.hearts, .ten), Card(.hearts, .jack), Card(.clubs, .four)])
        var match = try! Match(deck: deck, dealer: 3)
        try! match.bid(seat: 0, amount: nil)
        try! match.bid(seat: 1, amount: 2)
        try! match.bid(seat: 2, amount: nil)
        try! match.bid(seat: 3, amount: nil)
        try! match.chooseTrump(seat: 1, suit: .spades)
        // Play goes 1, 2, 3, then you: seat 1 leads a heart and the others follow, so you act last.
        try! match.play(seat: 1, card: Card(.hearts, .nine))
        try! match.play(seat: 2, card: Card(.hearts, .two))
        try! match.play(seat: 3, card: Card(.hearts, .ten))
        return match
    }

    /// Dealer 0: seat 1 bids 3, seats 2 and 3 pass, and the dealer is to act.
    private static func dealerMatchPosition() -> Match {
        let all = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
        var match = try! Match(deck: all, dealer: 0)
        try! match.bid(seat: 1, amount: 3)
        try! match.bid(seat: 2, amount: nil)
        try! match.bid(seat: 3, amount: nil)
        return match
    }

    /// Hand 1: you hold the six lowest clubs, bid 9 and name clubs; the other team holds every higher
    /// club, so the bid fails and you drop to −9. Hand 2: everyone passes to you, the dealer.
    private static func nineAndOutBelowZeroPosition() -> Match {
        let deck = deck(
            seat0: [Card(.clubs, .two), Card(.clubs, .three), Card(.clubs, .four), Card(.clubs, .five), Card(.clubs, .six), Card(.clubs, .seven)],
            seat1: [Card(.clubs, .ace), Card(.clubs, .king), Card(.clubs, .queen), Card(.hearts, .two), Card(.hearts, .three), Card(.hearts, .four)],
            seat2: [Card(.diamonds, .two), Card(.diamonds, .three), Card(.diamonds, .four), Card(.diamonds, .five), Card(.diamonds, .six), Card(.diamonds, .seven)],
            seat3: [Card(.clubs, .jack), Card(.clubs, .ten), Card(.clubs, .nine), Card(.hearts, .five), Card(.hearts, .six), Card(.hearts, .seven)],
            stock: [])
        var match = try! Match(deck: deck, dealer: 3)
        try! match.bid(seat: 0, amount: 9)
        for seat in 1...3 { try! match.bid(seat: seat, amount: nil) }
        try! match.chooseTrump(seat: 0, suit: .clubs)
        while match.hand.phase == .playing, let seat = match.hand.nextSeat {
            guard let view = try? PlayerView(match: match, seat: seat),
                  let reply = ComputerPlayer.decide(view, difficulty: .standard),
                  (try? match.apply(reply, seat: seat)) != nil else { break }
        }
        let next = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
        try! match.startNextHand(deck: next)
        for seat in 1...3 { try! match.bid(seat: seat, amount: nil) }
        return match
    }
}
