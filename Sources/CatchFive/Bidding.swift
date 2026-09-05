public enum Bid: Equatable, Sendable {
    case points(Int)
    case nineAndOut
}

/// One bidding round; nine and out outranks normal nine and dealer may match.
public struct Auction: Sendable {
    public private(set) var isNineAndOut = false
    public let dealer: Int
    public private(set) var nextSeat: Int?
    public private(set) var winner: Int?
    public private(set) var highestBid: Int?

    public init(dealer: Int) throws {
        guard (0..<4).contains(dealer) else { throw RuleError.invalidSeat }
        self.dealer = dealer
        nextSeat = (dealer + 1) % 4
    }

    public mutating func act(seat: Int, bid: Int?, nineAndOut: Bool = false) throws {
        guard let nextSeat else { throw RuleError.auctionComplete }
        guard seat == nextSeat else { throw RuleError.outOfTurn }
        if nineAndOut {
            guard bid == 9, !isNineAndOut || seat == dealer else { throw RuleError.invalidBid }
            highestBid = 9
            winner = seat
            isNineAndOut = true
        } else if let bid {
            let minimum = highestBid.map { $0 + (seat == dealer ? 0 : 1) } ?? 2
            guard !isNineAndOut, (2...9).contains(bid), bid >= minimum else { throw RuleError.invalidBid }
            highestBid = bid
            winner = seat
        } else if seat == dealer && highestBid == nil {
            throw RuleError.invalidBid
        }
        self.nextSeat = seat == dealer ? nil : (seat + 1) % 4
    }
}
