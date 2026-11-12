import CatchFive
import SwiftUI

struct BiddingLesson: View {
    @ObservedObject var model: TutorialModel

    var body: some View {
        VStack(spacing: 16) {
            Text("High bid: 3. Your bid.").font(.headline)
            HStack(spacing: 8) {
                SeatTile(name: Settings.defaultSeatNames[1], detail: "West · Bid 2", portrait: Cast.opponents[0].portrait, figure: SeatArt.image(seat: 1, opponents: .friends)) {}
                SeatTile(name: Settings.defaultSeatNames[2], detail: "Partner · Bid 3", portrait: Cast.opponents[1].portrait, figure: SeatArt.image(seat: 2, opponents: .friends)) {}
                SeatTile(name: Settings.defaultSeatNames[3], detail: "East · Waiting", badge: "DEALER", portrait: Cast.opponents[2].portrait, figure: SeatArt.image(seat: 3, opponents: .friends)) {}
            }.fixedSize(horizontal: false, vertical: true).disabled(true)   // one height, the badge or not
            HStack(spacing: 8) { ForEach(TutorialFixtures.biddingHand, id: \.self) { CardView(card: $0) } }
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
                ForEach(2...9, id: \.self) { amount in bidButton(String(amount), .points(amount)) }
            }
            HStack { bidButton("Pass", .pass); bidButton("9 and out", .nineAndOut) }
            Feedback(text: model.bidFeedback)
            
            DisclosureGroup("Why?") {
                LessonText(paragraphs: [
                    "Bidding starts on the dealer's left and goes around once. A bid is how many of the nine points your team promises to take, from 2 to 9.",
                    "Each bid must beat the last; the dealer may match the high bid instead. If everyone passes, the dealer must bid 2.",
                    "The high bidder names trump and leads. Make the bid and you keep every point you took. Fall short and you lose the whole bid.",
                ], tactic: "Count what you can see: an ace in a long suit is High, a protected five is five. Bid what you can take.")
            }
        }
    }

    private func bidButton(_ label: String, _ bid: TutorialBid) -> some View {
        let legal = TutorialFixtures.legalBids.contains(bid)
        let picked = model.bidPick == bid
        return Button(label) { model.chooseBid(bid) }
            .buttonStyle(PaperTileStyle()).frame(minHeight: 44)
            .opacity(legal ? 1 : 0.35)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(picked ? (bid == TutorialFixtures.preferredBid ? Color.correctRing : .incorrectRing) : .clear, lineWidth: 3))
            .accessibilityValue(legal ? "legal" : "not legal: must raise above 3")
    }
}
