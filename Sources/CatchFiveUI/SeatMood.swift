import CatchFive

/// What a seat's face shows, from public events only: whose turn it is, who took the last trick, who
/// won the match. Nothing here looks at a hand, so an expression can never leak a card.
enum SeatMood {
    static func expression(for seat: Int, in match: Match, matchWinner: Int? = nil) -> Portrait.Expression {
        if let winner = matchWinner ?? match.winner {
            return seat % 2 == winner % 2 ? .triumphant : .dismayed
        }
        let hand = match.hand
        if hand.nextSeat == seat, hand.phase != .finished { return .thinking }
        // A finished trick still on the table: the takers are pleased, the others rueful, until the next lead.
        if hand.phase == .playing, hand.currentTrick.isEmpty, let last = hand.completedTricks.last {
            return seat % 2 == last.winner % 2 ? .pleased : .rueful
        }
        return .neutral
    }
}
