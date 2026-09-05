public enum Bid: Equatable, Sendable {
    case points(Int)
    case nineAndOut
}

/// Normal bidding only. Special declaration precedence needs a house-rule decision.
public struct Auction: Sendable {
    public let dealer: Int
    public private(set) var nextSeat: Int?
    public private(set) var winner: Int?
    public private(set) var highestBid: Int?

    public init(dealer: Int) throws {
        guard (0..<4).contains(dealer) else { throw RuleError.invalidSeat }
        self.dealer = dealer
        nextSeat = (dealer + 1) % 4
    }

    public mutating func act(seat: Int, bid: Int?) throws {
        guard let nextSeat else { throw RuleError.auctionComplete }
        guard seat == nextSeat else { throw RuleError.outOfTurn }
        if let bid {
            let minimum = highestBid.map { $0 + (seat == dealer ? 0 : 1) } ?? 2
            guard (2...9).contains(bid), bid >= minimum else { throw RuleError.invalidBid }
            highestBid = bid
            winner = seat
        } else if seat == dealer && highestBid == nil {
            throw RuleError.invalidBid
        }
        self.nextSeat = seat == dealer ? nil : (seat + 1) % 4
    }
}
