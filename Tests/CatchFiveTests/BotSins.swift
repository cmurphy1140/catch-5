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
        /// The trump Five or Jack thrown into a trick it could not even take the lead in.
        case gaveAwayACounter
        /// Took the trick off a partner whose card no remaining card could beat: nothing was gained.
        case overtookThePartner
        /// Bid, then finished two or more points short of the contract.
        case bidAndWasBadlySet
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
                context.append(PlayInContext(
                    seat: seat,
                    card: card,
                    hadAChoice: match.hand.legalMoves(seat: seat).count > 1,
                    leaderBefore: leader,
                    leaderWasSafe: leader.map { leaderIsSafe(before, from: seat, hands: match.hand.hands, trump: trump, leader: $0) } ?? false,
                    tookTheLead: before.isEmpty || beats(card, before.first(where: { $0.seat == leader })?.card ?? card,
                                                        led: before[0].card.suit, trump: trump)))
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
        guard play.hadAChoice else { continue }   // forced is never a mistake

        // Playing a counter to try to win a trick and being overtrumped is a bet that lost, not a
        // mistake. Playing one that did not even take the lead is five points thrown at nothing.
        let isCounter = play.card.suit == trump && (play.card.rank == .five || play.card.rank == .jack)
        if isCounter, !play.tookTheLead, trick.winner % 2 != play.seat % 2 {
            sins.append(BotSin(kind: .gaveAwayACounter, seed: seed, hand: hand, seat: play.seat,
                               detail: "threw the \(play.card.name) under the trick seat \(trick.winner) took"))
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

    let overtaking = [PlayInContext(seat: 2, card: Card(.spades, .king), hadAChoice: true, leaderBefore: 0, leaderWasSafe: true, tookTheLead: true)]
    let taken = CompletedTrick(plays: trick.plays, winner: 2)
    let overtook = trickSins(taken, context: overtaking, trump: .spades, seed: 1, hand: 1)
    #expect(overtook.count == 1 && overtook[0].kind == .overtookThePartner)

    // The same overtake, when someone left could still have beaten the partner, is good play.
    let contested = [PlayInContext(seat: 2, card: Card(.spades, .king), hadAChoice: true, leaderBefore: 0, leaderWasSafe: false, tookTheLead: true)]
    #expect(trickSins(taken, context: contested, trump: .spades, seed: 1, hand: 1).isEmpty)

    // The trump Five handed to the other side, with another card in hand, is the counter sin.
    let surrender = [PlayInContext(seat: 1, card: Card(.spades, .five), hadAChoice: true, leaderBefore: 0, leaderWasSafe: false, tookTheLead: false)]
    let lost = trickSins(trick, context: surrender, trump: .spades, seed: 1, hand: 1)
    #expect(lost.count == 1 && lost[0].kind == .gaveAwayACounter)

    // The same Five played to take the lead, then overtrumped, is a bet that lost rather than waste.
    let gambled = [PlayInContext(seat: 1, card: Card(.spades, .five), hadAChoice: true, leaderBefore: 0, leaderWasSafe: false, tookTheLead: true)]
    #expect(trickSins(trick, context: gambled, trump: .spades, seed: 1, hand: 1).isEmpty)

    // The same play with no choice in hand is not a mistake, and is not counted as one.
    let forced = [PlayInContext(seat: 1, card: Card(.spades, .five), hadAChoice: false, leaderBefore: 0, leaderWasSafe: false, tookTheLead: false)]
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
