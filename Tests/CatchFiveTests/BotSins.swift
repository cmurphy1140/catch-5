import Testing
@testable import CatchFive

/// Hunting the computer's bad decisions so they can be flagged, reproduced and fixed (D58).
///
/// Connor named four sins from real play: bidding wrong, wasting a trick, ignoring the partner, and
/// giving away the Five or Jack. Three of them are mechanical, so a sweep of seeded matches can find
/// them without anyone watching. Each finding carries the seed, hand and trick that produced it, which
/// is everything a fixture needs.
///
/// This file only *counts*. What an acceptable rate is, and which sins are worth fixing first, is a
/// judgement call made on the numbers rather than guessed at here.
struct BotSin: CustomStringConvertible {
    enum Kind: String, CaseIterable {
        /// The trump Five thrown into a trick it could not take. Connor's table treats it as sacred.
        case surrenderedTheFive
        /// The trump Jack thrown into a trick it could not take: a point handed over.
        case surrenderedTheJack
        /// A trump nothing lower could follow, thrown into a lost trick: the Low point given away.
        /// Early, with lower trumps still to come, the same card is ordinary play and is not counted.
        case surrenderedTheLow
        /// A ten thrown into a lost trick. Worth 10 toward Game, more than an ace's 4.
        case surrenderedATen
        /// Took the trick off a partner whose card no remaining card could beat: nothing was gained.
        case overtookThePartner
        /// Bid, then finished two or more points short of the contract.
        case bidAndWasBadlySet
        /// Passed or underbid a hand Connor's table would have bid, with the number still available.
        case underbidAGoodHand
    }

    let kind: Kind
    let seed: Int
    let hand: Int
    let seat: Int
    let detail: String

    var description: String { "seed \(seed) hand \(hand) seat \(seat): \(detail)" }
}

/// Who holds a part-played trick. `trickWinner` answers only once all four cards are down; this is
/// the same rule asked of what is on the table so far, which is what a seat has to beat to take it.
func leaderSoFar(_ plays: [Play], trump: Suit) -> Int? {
    guard let led = plays.first?.card.suit else { return nil }
    let trumps = plays.filter { $0.card.suit == trump }
    let candidates = trumps.isEmpty ? plays.filter { $0.card.suit == led } : trumps
    return candidates.max { $0.card.rank.rawValue < $1.card.rank.rawValue }?.seat
}

/// One play, with the facts a detector needs that the finished trick no longer remembers: who was
/// winning when it was made, whether the seat had any choice, and — from outside the game, where a
/// test may look at every hand — whether the leader's card was already safe from everyone still to play.
struct PlayInContext {
    let seat: Int
    let card: Card
    let hadAChoice: Bool
    let leaderBefore: Int?
    /// True when no card left in a later seat's hand could have beaten the card then leading.
    let leaderWasSafe: Bool
    /// True when this card took the lead as it was played. A card that did not cannot win the trick.
    let tookTheLead: Bool
    /// True when no lower trump remained anywhere unplayed, so this card was certainly the Low.
    /// Judged with every hand and the stock in view, which is what "nothing lower may still show
    /// up" means in practice.
    let isCertainlyLow: Bool
    /// True when a legal card in the same hand would have surrendered less. Having a choice is not
    /// the same as having a cheaper one: a seat forced to throw its least bad card made no mistake.
    let hadACheaperCard: Bool
}

/// What losing this card to the other side costs, in the terms Connor's table scores: the Five is
/// five of the nine points, the Jack and a certain Low one each, and card value counts toward Game.
func surrenderCost(_ card: Card, trump: Suit, certainlyLow: Bool) -> Double {
    var cost = Double(card.rank.gameValue) * 0.1
    if card.suit == trump && card.rank == .five { cost += 5 }
    if card.suit == trump && card.rank == .jack { cost += 1 }
    if certainlyLow { cost += 1 }
    return cost
}

/// Plays `seeds` matches with the standard player in all four seats and reports every sin it sees.
func huntBotSins(seeds: Range<Int>) throws -> [BotSin] {
    let deck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }
    var sins: [BotSin] = []

    for seed in seeds {
        var random = RepeatableRandom(state: UInt64(seed))
        var match = try Match(deck: deck.shuffled(using: &random), dealer: seed % 4)
        var context: [PlayInContext] = []
        var handsSeen = 0

        while match.winner == nil {
            if match.hand.phase == .finished {
                if let summary = match.history.last { sins += setSins(summary, seed: seed) }
                handsSeen += 1
                context = []
                try match.startNextHand(deck: deck.shuffled(using: &random))
                continue
            }
            guard let seat = match.hand.nextSeat,
                  let action = try ComputerPlayer.decide(PlayerView(match: match, seat: seat)) else { break }

            // Capture what the seat could see before the card leaves its hand.
            if case let .play(card) = action, let trump = match.hand.trump {
                let before = match.hand.currentTrick
                let leader = leaderSoFar(before, trump: trump)
                let legal = match.hand.legalMoves(seat: seat)
                let certainlyLow = card.suit == trump && noLowerTrumpRemains(than: card, hand: match.hand, trump: trump)
                context.append(PlayInContext(
                    seat: seat,
                    card: card,
                    hadAChoice: legal.count > 1,
                    leaderBefore: leader,
                    leaderWasSafe: leader.map { leaderIsSafe(before, from: seat, hands: match.hand.hands, trump: trump, leader: $0) } ?? false,
                    tookTheLead: before.isEmpty || beats(card, before.first(where: { $0.seat == leader })?.card ?? card,
                                                        led: before[0].card.suit, trump: trump),
                    isCertainlyLow: certainlyLow,
                    hadACheaperCard: legal.contains {
                        surrenderCost($0, trump: trump,
                                      certainlyLow: $0.suit == trump && noLowerTrumpRemains(than: $0, hand: match.hand, trump: trump))
                            < surrenderCost(card, trump: trump, certainlyLow: certainlyLow)
                    }))
            }

            if case let .bid(amount) = action {
                sins += biddingSins(cards: match.hand.hands[seat], bid: amount,
                                    highestBid: match.hand.auction.highestBid,
                                    seat: seat, seed: seed, hand: handsSeen + 1)
            }

            let tricksBefore = match.hand.completedTricks.count
            try match.apply(action, seat: seat)

            // A finished trick is the only moment both the choice and the outcome are known.
            if match.hand.completedTricks.count > tricksBefore,
               let finished = match.hand.completedTricks.last, let trump = match.hand.trump {
                sins += trickSins(finished, context: context, trump: trump,
                                  seed: seed, hand: handsSeen + 1)
                context = []
            }
        }
        if let summary = match.history.last, match.winner != nil {
            sins += setSins(summary, seed: seed)
        }
    }
    return sins
}

/// Could anybody still to play, this seat included, have beaten the card currently leading? A test
/// may ask this with every hand in view, which the strategy itself may not. When the answer is no,
/// the trick was already won and taking it off a partner gains nothing.
func leaderIsSafe(_ trick: [Play], from seat: Int, hands: [[Card]], trump: Suit, leader: Int) -> Bool {
    guard let leading = trick.first(where: { $0.seat == leader })?.card else { return false }
    let led = trick[0].card.suit
    let played = Set(trick.map(\.seat))
    for other in 0..<4 where !played.contains(other) {
        if legalCards(in: hands[other], led: led).contains(where: { beats($0, leading, led: led, trump: trump) }) {
            return false
        }
    }
    return true
}

/// Is every trump lower than `card` already gone? Only then is `card` certainly the Low, and only
/// then is losing it a point given away rather than a card played before anything lower turned up.
func noLowerTrumpRemains(than card: Card, hand: Hand, trump: Suit) -> Bool {
    let unplayed = hand.hands.flatMap { $0 } + hand.stock
    return !unplayed.contains { $0.suit == trump && $0.rank.rawValue < card.rank.rawValue && $0 != card }
}

/// Does `card` take the trick from `leading`? Trump beats a non-trump; otherwise only a higher card
/// of the same suit does, and a card off both trump and the led suit beats nothing.
func beats(_ card: Card, _ leading: Card, led: Suit, trump: Suit) -> Bool {
    if card.suit == trump { return leading.suit != trump || card.rank.rawValue > leading.rank.rawValue }
    if leading.suit == trump || card.suit != leading.suit { return false }
    return card.rank.rawValue > leading.rank.rawValue
}

/// Sins visible once a trick is complete: a counter surrendered, or a partner overtaken.
func trickSins(_ trick: CompletedTrick, context: [PlayInContext], trump: Suit,
                       seed: Int, hand: Int) -> [BotSin] {
    var sins: [BotSin] = []
    for play in context {
        // Forced is never a mistake, and neither is throwing the cheapest card you hold.
        guard play.hadAChoice, play.hadACheaperCard else { continue }

        // A card played to take the lead and then beaten is a bet that lost, not a mistake. Only a
        // card that never took the lead was thrown at a trick it could not win.
        let lost = !play.tookTheLead && trick.winner % 2 != play.seat % 2
        if lost {
            // Feeding a card to a partner who holds the trick is "sneaking", and it is how points
            // reach your own side. That the partner was then overtrumped is a bet that lost. The
            // Five is the exception: Connor's table treats it as sacred and never risks it at all.
            let fedToPartner = play.leaderBefore.map { $0 % 2 == play.seat % 2 && $0 != play.seat } ?? false
            let kind: BotSin.Kind?
            if play.card.suit == trump && play.card.rank == .five { kind = .surrenderedTheFive }
            else if fedToPartner { kind = nil }
            else if play.card.suit == trump && play.card.rank == .jack { kind = .surrenderedTheJack }
            else if play.isCertainlyLow { kind = .surrenderedTheLow }
            else if play.card.rank == .ten { kind = .surrenderedATen }
            else { kind = nil }
            if let kind {
                sins.append(BotSin(kind: kind, seed: seed, hand: hand, seat: play.seat,
                                   detail: "threw the \(play.card.name) under the trick seat \(trick.winner) took"))
            }
        }

        // Overtaking a partner who might still lose the trick is ordinary good play. Only taking it
        // from a partner nobody left could beat is indefensible: the trick was already won.
        if let leader = play.leaderBefore, leader % 2 == play.seat % 2, leader != play.seat,
           trick.winner == play.seat, play.leaderWasSafe {
            sins.append(BotSin(kind: .overtookThePartner, seed: seed, hand: hand, seat: play.seat,
                               detail: "overtook partner \(leader), whose card was already safe, with the \(play.card.name)"))
        }
    }
    return sins
}

/// Connor's table bids a hand by its best suit, September 14, 2026. Unwritten rules at a real
/// table, written down here so the computer can be measured against them. They are floors, not
/// ceilings: bidding higher to keep the auction away from the other side is a legitimate move.
///
/// | Holding in one suit | Bid |
/// |---|---|
/// | three or more, including that suit's five | 5 |
/// | ace and king | 3 |
/// | ace and queen | 2 |
/// | ace and jack | 2 |
func houseBid(for cards: [Card]) -> Int? {
    var best: Int?
    for suit in Suit.allCases {
        let held = cards.filter { $0.suit == suit }
        let ranks = Set(held.map(\.rank))
        var floor: Int?
        if held.count >= 3 && ranks.contains(.five) { floor = 5 }
        else if ranks.contains(.ace) && ranks.contains(.king) { floor = 3 }
        else if ranks.contains(.ace) && (ranks.contains(.queen) || ranks.contains(.jack)) { floor = 2 }
        if let floor, floor > (best ?? 0) { best = floor }
    }
    return best
}

/// Passing or underbidding a hand the table would have bid, while that number was still there to
/// take. A hand already bid past is not a sin to pass on.
func biddingSins(cards: [Card], bid: Int?, highestBid: Int?, seat: Int, seed: Int, hand: Int) -> [BotSin] {
    guard let floor = houseBid(for: cards), (highestBid ?? 0) < floor, (bid ?? 0) < floor else { return [] }
    let said = bid.map { "bid \($0)" } ?? "passed"
    return [BotSin(kind: .underbidAGoodHand, seed: seed, hand: hand, seat: seat,
                   detail: "\(said) on a hand the table bids \(floor)")]
}

/// The bidding sin: a contract missed by a clear margin rather than by one point.
private func setSins(_ summary: HandSummary, seed: Int) -> [BotSin] {
    guard !summary.isNineAndOut else { return [] }
    let captured = summary.result.points[summary.bidder % 2]
    guard captured <= summary.bid - 2 else { return [] }
    return [BotSin(kind: .bidAndWasBadlySet, seed: seed, hand: summary.number, seat: summary.bidder,
                   detail: "bid \(summary.bid) and captured \(captured)")]
}

@Test func theDetectorNamesAnOvertakenPartnerAndASurrenderedCounterAndForgivesTheForced() throws {
    // Spades are trump. Seat 0 leads the ace, seat 1 follows low, so seat 2 — seat 0's partner —
    // arrives with the trick already won and takes it off them anyway.
    let trick = CompletedTrick(plays: [
        Play(seat: 0, card: Card(.spades, .ace)),
        Play(seat: 1, card: Card(.spades, .three)),
        Play(seat: 2, card: Card(.spades, .two)),
        Play(seat: 3, card: Card(.spades, .four)),
    ], winner: 0)
    #expect(leaderSoFar(Array(trick.plays.prefix(2)), trump: .spades) == 0)

    let overtaking = [PlayInContext(seat: 2, card: Card(.spades, .king), hadAChoice: true, leaderBefore: 0, leaderWasSafe: true, tookTheLead: true, isCertainlyLow: false, hadACheaperCard: true)]
    let taken = CompletedTrick(plays: trick.plays, winner: 2)
    let overtook = trickSins(taken, context: overtaking, trump: .spades, seed: 1, hand: 1)
    #expect(overtook.count == 1 && overtook[0].kind == .overtookThePartner)

    // The same overtake, when someone left could still have beaten the partner, is good play.
    let contested = [PlayInContext(seat: 2, card: Card(.spades, .king), hadAChoice: true, leaderBefore: 0, leaderWasSafe: false, tookTheLead: true, isCertainlyLow: false, hadACheaperCard: true)]
    #expect(trickSins(taken, context: contested, trump: .spades, seed: 1, hand: 1).isEmpty)

    // The trump Five handed to the other side, with another card in hand, is the counter sin.
    let surrender = [PlayInContext(seat: 1, card: Card(.spades, .five), hadAChoice: true, leaderBefore: 0, leaderWasSafe: false, tookTheLead: false, isCertainlyLow: false, hadACheaperCard: true)]
    let lost = trickSins(trick, context: surrender, trump: .spades, seed: 1, hand: 1)
    #expect(lost.count == 1 && lost[0].kind == .surrenderedTheFive)

    // The same Five played to take the lead, then overtrumped, is a bet that lost rather than waste.
    let gambled = [PlayInContext(seat: 1, card: Card(.spades, .five), hadAChoice: true, leaderBefore: 0, leaderWasSafe: false, tookTheLead: true, isCertainlyLow: false, hadACheaperCard: true)]
    #expect(trickSins(trick, context: gambled, trump: .spades, seed: 1, hand: 1).isEmpty)

    // The same play with no choice in hand is not a mistake, and is not counted as one.
    let forced = [PlayInContext(seat: 1, card: Card(.spades, .five), hadAChoice: false, leaderBefore: 0, leaderWasSafe: false, tookTheLead: false, isCertainlyLow: false, hadACheaperCard: false)]
    #expect(trickSins(trick, context: forced, trump: .spades, seed: 1, hand: 1).isEmpty)
}

@Test func botSinsAcrossManySeededMatchesAreCountedAndReported() throws {
    let sins = try huntBotSins(seeds: 1..<121)
    var lines = ["Bot sins over 120 seeded matches:"]
    for kind in BotSin.Kind.allCases {
        let found = sins.filter { $0.kind == kind }
        lines.append("  \(kind.rawValue): \(found.count)")
        for sin in found.prefix(3) { lines.append("      \(sin)") }
    }
    print(lines.joined(separator: "\n"))
    // The sweep is a report, not yet a ceiling: the numbers decide what a fair ceiling is.
    #expect(sins.allSatisfy { BotSin.Kind.allCases.contains($0.kind) })
}

@Test func noMoreCountersAreThrownAwayThanTheDayTheHuntWasBuilt() throws {
    // A ratchet, not a target. Fourteen counters are surrendered today: 12 Jacks and 2 Fives, each
    // thrown at a trick it could not take with a cheaper card in hand. The goal is zero — Connor's
    // table treats the Five as sacred and the Jack is a point like any other — but the likeliest
    // cure is not tuning `chooseCard`. It is giving the strategy the discard counts it has never
    // had, so it can tell a loaded opponent from an empty one. Lower this number when that lands.
    let counters = try huntBotSins(seeds: 1..<121)
        .filter { $0.kind == .surrenderedTheFive || $0.kind == .surrenderedTheJack }
    #expect(counters.count <= 14, "regression: \(counters.count) counters thrown away")

    // Tens and low trumps have their own floors, kept apart because they are worth different points.
    let all = try huntBotSins(seeds: 1..<121)
    #expect(all.filter { $0.kind == .surrenderedATen }.count <= 14)
    #expect(all.filter { $0.kind == .surrenderedTheLow }.count <= 19)
}
