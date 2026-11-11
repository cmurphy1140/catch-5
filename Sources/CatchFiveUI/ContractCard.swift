import CatchFive
import SwiftUI

/// The auction read back before the first card (D157): who took the bid, what each seat called, trump and the score,
/// on a scrap off the score pad. One tap and the hand begins. Everything on it was said aloud at the table.
struct ContractCard: View {
    struct Summary: Equatable {
        let headline: String
        /// Each seat's last call, in the order they spoke.
        let calls: [Call]
        let trump: Suit?
        let us: Int
        let them: Int

        struct Call: Equatable, Identifiable {
            let name: String
            let words: String
            let won: Bool
            var id: String { name }
        }

        init?(auction: Auction, trump: Suit?, names: [String], scores: [Int], ourTeam: Int) {
            guard auction.nextSeat == nil, let winner = auction.winner, let bid = auction.highestBid else { return nil }
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
                return Call(name: names[seat], words: words, won: seat == winner)
            }
            self.trump = trump
            us = scores[ourTeam]
            them = scores[1 - ourTeam]
        }
    }

    let summary: Summary
    let onPlay: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea()
            VStack(spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(summary.headline).font(.custom("Noteworthy-Bold", fixedSize: 25)).fixedSize(horizontal: false, vertical: true)
                    VStack(spacing: 4) {
                        ForEach(summary.calls) { call in
                            HStack {
                                Text(call.name)
                                Spacer(minLength: 12)
                                Text(call.words)
                            }
                            .font(.custom(call.won ? "Noteworthy-Bold" : "Noteworthy-Light", fixedSize: 21))
                            .overlay(alignment: .bottom) { if call.won { Rectangle().fill(Color.suitRed).frame(height: 2).offset(y: 1) } }
                        }
                    }
                    if let trump = summary.trump {
                        HStack(spacing: 8) {
                            Text("Trump")
                            Spacer(minLength: 12)
                            Text(trump.glyph).foregroundStyle(trump.isRed ? Color.suitRed : Theme.Paper.ink)
                            Text("\(trump)".capitalized)
                        }
                        .font(.custom("Noteworthy-Bold", fixedSize: 21))
                    }
                    HStack {
                        Text("Us \(summary.us)")
                        Spacer(minLength: 12)
                        Text("Them \(summary.them)")
                    }
                    .font(.custom("Noteworthy-Light", fixedSize: 21))
                }
                .foregroundStyle(Theme.Paper.ink)
                .padding(.leading, 44).padding(.trailing, 26).padding(.top, 30).padding(.bottom, 24)
                .frame(width: 300)
                .background {
                    TornScrap().fill(Color.ivory).shadow(color: .black.opacity(0.45), radius: 8, y: 5)
                        .overlay(alignment: .leading) { Rectangle().fill(Color.suitRed.opacity(0.55)).frame(width: 1.5).padding(.leading, 32).padding(.vertical, 8) }
                }
                .rotationEffect(.degrees(-1.5))
                .accessibilityElement(children: .combine)
                Button("Play", action: onPlay).buttonStyle(WoodWritingButtonStyle(size: 26)).frame(width: 150)
                    .keyboardShortcut(.defaultAction)
            }
            .padding(20)
        }
        .accessibilityAddTraits(.isModal)
    }
}
