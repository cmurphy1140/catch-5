/// Only this player's cards and public information cross the strategy boundary.
public struct PlayerView: Sendable {
    public let seat: Int
    public let cards: [Card]
    public let phase: HandPhase
    public let nextSeat: Int?
    public let dealer: Int
    public let highestBid: Int?
    public let bidder: Int?
    public let trump: Suit?
    public let trick: [Play]
    public let calls: [AuctionCall]
    /// Every card already played this hand is public knowledge.
    public let completedTricks: [CompletedTrick]

    public init(seat: Int, cards: [Card], phase: HandPhase, nextSeat: Int?, dealer: Int,
                highestBid: Int?, bidder: Int?, trump: Suit?, trick: [Play], calls: [AuctionCall] = [],
                completedTricks: [CompletedTrick] = []) {
        self.seat = seat
        self.cards = cards
        self.phase = phase
        self.nextSeat = nextSeat
        self.dealer = dealer
        self.highestBid = highestBid
        self.bidder = bidder
        self.trump = trump
        self.trick = trick
        self.calls = calls
        self.completedTricks = completedTricks
    }
}

extension PlayerView {
    public init(match: Match, seat: Int) throws {
        guard (0..<4).contains(seat) else { throw RuleError.invalidSeat }
        let hand = match.hand
        self.init(seat: seat, cards: hand.hands[seat], phase: hand.phase,
                  nextSeat: match.winner == nil ? hand.nextSeat : nil,
                  dealer: hand.auction.dealer, highestBid: hand.auction.highestBid,
                  bidder: hand.auction.winner, trump: hand.trump, trick: hand.currentTrick,
                  calls: hand.auction.calls, completedTricks: hand.completedTricks)
    }
}

extension PlayerView {
    /// The view `play.seat` had just before making `play`, rebuilt from public information and
    /// that seat's remaining cards: pass nil for a card still on the table, or the index of the
    /// completed trick it belongs to. Explains earlier plays with the same code that made them.
    public init(match: Match, replaying play: Play, inCompletedTrick index: Int?) throws {
        let hand = match.hand
        guard (0..<4).contains(play.seat) else { throw RuleError.invalidSeat }
        let trick: [Play], earlier: [CompletedTrick], later: [Play]
        if let index {
            guard hand.completedTricks.indices.contains(index) else { throw HandError.cardNotHeld }
            let plays = hand.completedTricks[index].plays
            guard let position = plays.firstIndex(of: play) else { throw HandError.cardNotHeld }
            trick = Array(plays[..<position])
            earlier = Array(hand.completedTricks[..<index])
            later = Array(plays[position...]) + hand.completedTricks[(index + 1)...].flatMap(\.plays) + hand.currentTrick
        } else {
            guard let position = hand.currentTrick.firstIndex(of: play) else { throw HandError.cardNotHeld }
            trick = Array(hand.currentTrick[..<position])
            earlier = hand.completedTricks
            later = Array(hand.currentTrick[position...])
        }
        let cards = hand.hands[play.seat] + later.filter { $0.seat == play.seat }.map(\.card)
        self.init(seat: play.seat, cards: cards, phase: .playing, nextSeat: play.seat,
                  dealer: hand.auction.dealer, highestBid: hand.auction.highestBid,
                  bidder: hand.auction.winner, trump: hand.trump, trick: trick,
                  calls: hand.auction.calls, completedTricks: earlier)
    }
}

public enum PlayerAction: Equatable, Sendable {
    case nineAndOut
    case bid(Int?)
    case chooseTrump(Suit)
    case play(Card)
}

/// A recommended action with the reasoning behind it in plain words.
public struct Advice: Equatable, Sendable {
    public let action: PlayerAction
    public let reason: String
}

/// How strong the computer seats play. Hints and explanations always use the standard strategy.
public enum Difficulty: String, Codable, CaseIterable, Sendable {
    case easy, standard
}

public enum ComputerPlayer {
    public static func decide(_ view: PlayerView) -> PlayerAction? { advise(view)?.action }

    /// The action a computer of the given difficulty takes from `view`'s seat.
    public static func decide(_ view: PlayerView, difficulty: Difficulty) -> PlayerAction? {
        switch difficulty {
        case .easy: EasyPlayer.decide(view)
        case .standard: decide(view)
        }
    }

    /// The action this strategy would take from `view`'s seat, with its reasoning. Nil when it is not that seat's turn.
    public static func advise(_ view: PlayerView) -> Advice? {
        guard view.nextSeat == view.seat else { return nil }
        switch view.phase {
        case .bidding: return bidAdvice(view)
        case .choosingTrump:
            let ranked = Suit.allCases.map { ($0, estimate(view.cards, suit: $0)) }.sorted { $0.1 > $1.1 }
            let runnerUp = ranked.dropFirst().first.map { ", ahead of \($0.0.rawValue) at \(tenths($0.1))" } ?? ""
            return Advice(action: .chooseTrump(preferredSuit(view.cards)),
                          reason: "Choose \(preferredSuit(view.cards).rawValue): your hand is worth about \(tenths(ranked[0].1)) points there\(runnerUp).")
        case .playing: return chooseCard(view).map { Advice(action: .play($0.card), reason: $0.reason) }
        case .finished: return nil
        }
    }

    static func tenths(_ value: Double) -> String {
        let scaled = Int((value * 10).rounded())
        return "\(scaled / 10).\(scaled % 10)"
    }

    private static func preferredSuit(_ cards: [Card]) -> Suit {
        // Fixed suit order makes equal-strength choices repeatable.
        Suit.allCases.max { estimate(cards, suit: $0) < estimate(cards, suit: $1) } ?? .clubs
    }

    /// Expected hand points if `suit` were trump, judged before the discard and refill.
    /// Weights are playtesting heuristics, not derived probabilities.
    static func estimate(_ cards: [Card], suit: Suit) -> Double {
        let trumps = cards.filter { $0.suit == suit }.map(\.rank.rawValue).sorted()
        guard let top = trumps.last, let bottom = trumps.first else { return 0 }
        let control = trumps.filter { $0 >= Rank.king.rawValue }.count
        var points = 0.0
        points += [Rank.ace.rawValue: 1.0, Rank.king.rawValue: 0.75, Rank.queen.rawValue: 0.45][top] ?? 0.2
        points += [Rank.two.rawValue: 1.0, Rank.three.rawValue: 0.75, Rank.four.rawValue: 0.5][bottom] ?? 0.2
        if trumps.contains(Rank.jack.rawValue) { points += control > 0 ? 0.8 : 0.4 }
        if trumps.contains(Rank.five.rawValue) {
            points += 2.5 + Double(control) * 0.75 + Double(trumps.count - 1) * 0.25
        } else if control >= 2 {
            points += 0.75
        }
        points += 0.5 + Double(max(0, trumps.count - 2)) * 0.3
        points += Double(6 - trumps.count) * 0.1 // Refill may bring more trumps.
        return points
    }

    private static func bidAdvice(_ view: PlayerView) -> Advice {
        if let bidder = view.bidder, bidder % 2 == view.seat % 2 {
            return Advice(action: .bid(nil), reason: "Pass: your partner already holds the bid at \(view.highestBid ?? 0), and bidding against a partner only raises the price.")
        }
        let isDealer = view.seat == view.dealer
        let needed = view.highestBid.map { $0 + (isDealer ? 0 : 1) } ?? 2
        let suit = preferredSuit(view.cards)
        let worth = estimate(view.cards, suit: suit)
        let hand = "your best suit is \(suit.rawValue), worth about \(tenths(worth)) points"
        // Bid up to the whole-point estimate; benchmarking showed a safety margin costs more than it saves.
        let confidence = Int(worth.rounded(.down))
        if needed <= min(confidence, 9) {
            let how = view.highestBid == nil ? "opens the bidding" : (isDealer ? "matches the high bid as dealer" : "is the smallest raise")
            return Advice(action: .bid(needed), reason: "Bid \(needed): \(hand), and \(needed) \(how).")
        }
        if isDealer && view.highestBid == nil {
            return Advice(action: .bid(2), reason: "Bid 2: everyone passed, so the dealer must open at two even though \(hand).")
        }
        return Advice(action: .bid(nil), reason: "Pass: \(hand), short of the \(needed) you would need to bid.")
    }

    // MARK: - Card play

    /// What one seat can infer from its own cards and the cards already played.
    struct Knowledge {
        let trump: Suit
        let hand: [Card]
        /// Cards neither held nor yet played: they sit in other hands or the undealt stock.
        let unseen: Set<Card>
        let isLastTrick: Bool

        init(view: PlayerView, trump: Suit) {
            self.trump = trump
            hand = view.cards
            var seen = Set(view.cards)
            for trick in view.completedTricks { seen.formUnion(trick.plays.map(\.card)) }
            seen.formUnion(view.trick.map(\.card))
            let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
            unseen = Set(deck).subtracting(seen)
            isLastTrick = view.completedTricks.count == 5
        }

        /// True when no card another seat could still play beats `card` in a trick of `led`.
        func unbeatable(_ card: Card, led: Suit) -> Bool {
            let higherTrump = unseen.contains { $0.suit == trump && $0.rank.rawValue > card.rank.rawValue }
            if card.suit == trump { return !higherTrump }
            guard card.suit == led else { return false }
            let anyTrump = unseen.contains { $0.suit == trump }
            let higherInSuit = unseen.contains { $0.suit == led && $0.rank.rawValue > card.rank.rawValue }
            return !anyTrump && !higherInSuit
        }

        /// Hand points the capturing team gains from this card. High and Low count only when
        /// certain, judged against every trump that could still sit in another hand; guessing
        /// at probable High/Low measured worse than ignoring it. Game is worth 0.06 per card point.
        func pointValue(_ card: Card) -> Double {
            var points = Double(card.rank.gameValue) * 0.06
            guard card.suit == trump else { return points }
            if card.rank == .five { points += 5 }
            if card.rank == .jack { points += 1 }
            let elsewhere = unseen.union(hand.filter { $0 != card })
                .filter { $0.suit == trump }.map(\.rank.rawValue)
            if !elsewhere.contains(where: { $0 > card.rank.rawValue }) { points += 1 }
            if !elsewhere.contains(where: { $0 < card.rank.rawValue }) { points += 1 }
            return points
        }

        /// What keeping a trump in hand is worth for later tricks; nothing on the last trick.
        /// An unbeatable trump is worth most because it decides a trick of our choosing.
        func controlValue(_ card: Card) -> Double {
            guard card.suit == trump, !isLastTrick else { return 0 }
            return 0.1 + Double(card.rank.rawValue) * 0.02 + (unbeatable(card, led: trump) ? 0.8 : 0)
        }
    }

    private static func chooseCard(_ view: PlayerView) -> (card: Card, reason: String)? {
        guard let trump = view.trump else { return nil }
        let knowledge = Knowledge(view: view, trump: trump)
        // Canonical order makes the choice independent of how the hand happens to be arranged.
        let legal = legalCards(in: view.cards, led: view.trick.first?.card.suit).sorted {
            (Suit.allCases.firstIndex(of: $0.suit)!, $0.rank.rawValue) < (Suit.allCases.firstIndex(of: $1.suit)!, $1.rank.rawValue)
        }
        guard let lead = view.trick.first else { return chooseLead(legal, knowledge) }
        let led = lead.card.suit
        let current = view.trick.max { rank($0.card, led: led, trump: trump) < rank($1.card, led: led, trump: trump) }!
        let partnerWinning = current.seat % 2 == view.seat % 2
        let toCome = 3 - view.trick.count
        let atStake = view.trick.reduce(0.0) { $0 + knowledge.pointValue($1.card) }
        let holdChance = [1.0, 0.8, 0.6]   // chance a beatable winner survives 0, 1 or 2 later plays

        /// Expected points for our side from playing `card`, net of the control given up.
        func score(_ card: Card) -> Double {
            let beats = rank(card, led: led, trump: trump) > rank(current.card, led: led, trump: trump)
            let safe = knowledge.unbeatable(card, led: led)
            let stake = safe ? 0 : knowledge.pointValue(card)
            let ours: Double
            if beats { ours = safe ? 1 : holdChance[toCome] }
            else if partnerWinning { ours = knowledge.unbeatable(current.card, led: led) ? 1 : holdChance[toCome] }
            else { ours = toCome == 2 ? 0.3 : 0 }   // partner still to play only when we are second
            var result = ours * (atStake + stake) - (1 - ours) * stake - knowledge.controlValue(card)
            if beats && partnerWinning { result -= 0.15 }
            return result
        }
        // Ties fall to the card with the least control, then the lowest rank, for repeatable play.
        guard let card = legal.max(by: { a, b in
            (score(a), -knowledge.controlValue(a), -a.rank.rawValue)
                < (score(b), -knowledge.controlValue(b), -b.rank.rawValue)
        }) else { return nil }

        let beats = rank(card, led: led, trump: trump) > rank(current.card, led: led, trump: trump)
        let table = atStake >= 0.5 ? "about \(tenths(atStake)) points are on the table" : "there is little on the table"
        let five = Card(trump, .five)
        let keepsFive = legal.contains(five) && card != five ? " The five stays back." : ""
        let reason: String
        if beats {
            if knowledge.unbeatable(card, led: led) {
                reason = "Play the \(card.name): nothing still to come can beat it, and \(table)."
            } else {
                reason = "Play the \(card.name): it takes the trick for now, and \(table).\(keepsFive)"
            }
        } else if partnerWinning {
            if knowledge.unbeatable(current.card, led: led) {
                reason = "Play the \(card.name): partner's \(current.card.name) holds the trick, so the most valuable card goes to it."
            } else {
                reason = "Play the \(card.name): partner is winning for now, so a low card keeps the strong ones back.\(keepsFive)"
            }
        } else {
            reason = "Play the \(card.name): this trick cannot be won, so the card worth least goes.\(keepsFive)"
        }
        return (card, reason)
    }

    private static func chooseLead(_ legal: [Card], _ knowledge: Knowledge) -> (card: Card, reason: String)? {
        let trump = knowledge.trump
        let trumps = legal.filter { $0.suit == trump }
        let others = legal.filter { $0.suit != trump }
        // A trump nobody can beat draws trumps from the other hands, which is how a five gets caught.
        if let boss = trumps.filter({ knowledge.unbeatable($0, led: trump) }).max(by: { $0.rank.rawValue < $1.rank.rawValue }) {
            return (boss, "Lead the \(boss.name): no trump left can beat it, and leading trumps draws them out, which is how a five gets caught.")
        }
        // With no trumps left against us, the highest side card usually wins the trick.
        if !knowledge.unseen.contains(where: { $0.suit == trump }), let high = others.max(by: {
            (knowledge.unbeatable($0, led: $0.suit) ? 1 : 0, $0.rank.rawValue)
                < (knowledge.unbeatable($1, led: $1.suit) ? 1 : 0, $1.rank.rawValue) }) {
            return (high, "Lead the \(high.name): no trumps are left against this side, so the highest side card should win.")
        }
        // Otherwise exit cheaply: never the five, and prefer a side card over spending a trump.
        let exits = others.isEmpty ? trumps.filter { $0.rank != .five } : others
        guard let exit = (exits.isEmpty ? legal : exits).min(by: {
            (knowledge.pointValue($0) + knowledge.controlValue($0), $0.rank.rawValue)
                < (knowledge.pointValue($1) + knowledge.controlValue($1), $1.rank.rawValue)
        }) else { return nil }
        let five = trumps.contains(Card(trump, .five)) && exit != Card(trump, .five) ? " and the five" : ""
        return (exit, "Lead the \(exit.name): without a commanding trump, the card that risks least goes, keeping the trumps\(five) back.")
    }

    private static func rank(_ card: Card, led: Suit, trump: Suit) -> Int {
        let tier = card.suit == trump ? 200 : (card.suit == led ? 100 : 0)
        return tier + card.rank.rawValue
    }
}

extension Match {
    /// Human and computer actions use the same checked entry points.
    public mutating func apply(_ action: PlayerAction, seat: Int) throws {
        switch action {
        case .nineAndOut: try bidNineAndOut(seat: seat)
        case let .bid(amount): try bid(seat: seat, amount: amount)
        case let .chooseTrump(suit): try chooseTrump(seat: seat, suit: suit)
        case let .play(card): try play(seat: seat, card: card)
        }
    }
}
