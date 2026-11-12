import CatchFive
import SwiftUI

/// The auction read back before the first card (D157): who took the bid, what each seat called, trump and the score,
/// on a scrap off the score pad. One tap and the hand begins. Everything on it was said aloud at the table.
struct ContractCard: View {
    struct Summary: Equatable {
        let headline: String
        let bidderSeat: Int
        let bidder: String
        let bid: Int
        let isNineAndOut: Bool
        /// Each seat's last call, in the order they spoke.
        let calls: [Call]
        let trump: Suit?
        let us: Int
        let them: Int

        struct Call: Equatable, Identifiable {
            let seat: Int
            let name: String
            let words: String
            let won: Bool
            var id: Int { seat }
        }

        init?(auction: Auction, trump: Suit?, names: [String], scores: [Int], ourTeam: Int) {
            guard auction.nextSeat == nil, let winner = auction.winner, let bid = auction.highestBid else { return nil }
            bidderSeat = winner
            bidder = names[winner]
            self.bid = bid
            isNineAndOut = auction.isNineAndOut
            headline = "\(names[winner]) took the bid" + (auction.isNineAndOut ? " at nine and out" : " at \(bid)")
            var order: [Int] = []
            for call in auction.calls where !order.contains(call.seat) { order.append(call.seat) }
            calls = order.map { seat in
                let last = auction.calls.last { $0.seat == seat }?.bid
                let words = switch last {
                case nil: "Pass"
                case .nineAndOut?: "9 and out"
                case let .points(amount)?: "\(amount)"
                }
                return Call(seat: seat, name: names[seat], words: words, won: seat == winner)
            }
            self.trump = trump
            us = scores[ourTeam]
            them = scores[1 - ourTeam]
        }
    }

    let summary: Summary
    var portrait: Portrait?
    var figure: Image?
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            GeometryReader { geometry in
                ViewThatFits(in: .vertical) {
                    slip {
                        details.fixedSize(horizontal: false, vertical: true)
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    slip {
                        ScrollView { details }
                            .scrollBounceBehavior(.basedOnSize)
                    }
                }
                .frame(width: min(320, max(0, geometry.size.width - 40)))
                .frame(maxHeight: max(0, geometry.size.height - 40))
                .rotationEffect(.degrees(-1))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .accessibilityAddTraits(.isModal)
    }

    private func slip<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(spacing: 16) {
            content()
            Button("Play", action: onPlay)
                .buttonStyle(PaperButtonStyle())
                .keyboardShortcut(.defaultAction)
                .accessibilityHint("Puts down the score slip and begins play")
                .accessibilityIdentifier("contract.play")
        }
        .foregroundStyle(Theme.Paper.ink)
        .padding(.leading, 38).padding(.trailing, 22).padding(.vertical, 24)
        .background {
            TornScrap().fill(Color.ivory).shadow(color: .black.opacity(0.45), radius: 8, y: 5)
                .overlay(alignment: .leading) {
                    Rectangle().fill(Color.suitRed.opacity(0.55)).frame(width: 1.5)
                        .padding(.leading, 25).padding(.vertical, 8)
                }
        }
        .accessibilityElement(children: .contain)
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                if let portrait {
                    SeatFace(portrait: portrait, figure: figure, size: 44)
                        .accessibilityHidden(true)
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text(summary.bidder)
                        .font(.custom("Noteworthy-Bold", fixedSize: 25))
                        .fixedSize(horizontal: false, vertical: true)
                    Text("took the bid")
                        .font(.custom("Noteworthy-Light", fixedSize: 17))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                VStack(spacing: -4) {
                    Text("\(summary.bid)").font(.custom("Noteworthy-Bold", fixedSize: 48))
                    if summary.isNineAndOut {
                        Text("and out").font(.custom("Noteworthy-Bold", fixedSize: 15))
                    }
                }
                .fixedSize()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary.headline)

            if let trump = summary.trump {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(trump.glyph)
                        .font(.system(size: 32))
                        .foregroundStyle(trump.isRed ? Color.suitRed : Theme.Paper.ink)
                    Text("\(trump.rawValue.capitalized) trump")
                        .font(.custom("Noteworthy-Bold", fixedSize: 23))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(trump.rawValue.capitalized) are trump")
            }

            VStack(spacing: 5) {
                ForEach(summary.calls) { call in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(call.name).fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        Text(call.words).fixedSize()
                    }
                    .font(.custom(call.won ? "Noteworthy-Bold" : "Noteworthy-Light", fixedSize: 21))
                    .padding(.bottom, call.won ? 3 : 0)
                    .overlay(alignment: .bottom) {
                        if call.won { Rectangle().fill(Color.suitRed).frame(height: 1.5) }
                    }
                    .accessibilityElement(children: .combine)
                }
            }

            HStack {
                Text("Us \(summary.us)")
                Spacer(minLength: 12)
                Text("Them \(summary.them)")
            }
            .font(.custom("Noteworthy-Bold", fixedSize: 21))
            .accessibilityElement(children: .combine)
        }
    }
}
