import CatchFive
import SwiftUI

struct BiddingLesson: View {
    @ObservedObject var model: TutorialModel

    var body: some View {
        VStack(spacing: 16) {
            LessonText(paragraphs: [
                "Bidding starts on the dealer's left and goes around once, ending with the dealer. A bid is how many of the nine points your team promises to take: at least 2, at most 9.",
                "Each bid must beat the one before it, except that the dealer may match the high bid. If everyone passes, the dealer must bid 2. The high bidder names trump and leads first.",
                "Make your bid and you add every point you took. Fall short and you lose the whole bid instead.",
            ], tactic: "Count what you can see: the ace of a long suit is High, the five in that suit is five if you can protect it. Bid what you can take; a failed 4 costs more than being outbid.")
            HStack {
                SeatTile(name: Cast.opponents[0].name, detail: "West · Bid 2", portrait: Cast.opponents[0].portrait) {}
                Spacer()
                SeatTile(name: Cast.opponents[1].name, detail: "Partner · Bid 3", portrait: Cast.opponents[1].portrait) {}
                Spacer()
                SeatTile(name: Cast.opponents[2].name, detail: "East · Waiting", badge: "DEALER", portrait: Cast.opponents[2].portrait) {}
            }.disabled(true)
            Text("High bid: 3. Your bid.").font(.subheadline)
            HStack(spacing: 8) { ForEach(TutorialFixtures.biddingHand, id: \.self) { CardView(card: $0) } }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(2...9, id: \.self) { amount in bidButton(String(amount), .points(amount)) }
            }
            HStack { bidButton("Pass", .pass); bidButton("9 and out", .nineAndOut) }
            Feedback(text: model.bidFeedback)
        }
    }

    private func bidButton(_ label: String, _ bid: TutorialBid) -> some View {
        let legal = TutorialFixtures.legalBids.contains(bid)
        let picked = model.bidPick == bid
        return Button(label) { model.chooseBid(bid) }
            .buttonStyle(.bordered).tint(.ivory.opacity(0.8)).frame(minHeight: 44)
            .opacity(legal ? 1 : 0.35)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(picked ? (bid == TutorialFixtures.preferredBid ? Color.correctRing : .incorrectRing) : .clear, lineWidth: 3))
            .accessibilityValue(legal ? "legal" : "not legal: must raise above 3")
    }
}
