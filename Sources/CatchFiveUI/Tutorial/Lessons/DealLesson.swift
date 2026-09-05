import CatchFive
import SwiftUI

struct DealLesson: View {
    @ObservedObject var model: TutorialModel
    private let names = Settings.defaultSeatNames

    var body: some View {
        VStack(spacing: 16) {
            LessonText(paragraphs: [
                "Four people sit around the table. You and the player across from you are partners; West and East are the other team.",
                "One player is the dealer. Six cards go to each player, three at a time, starting with the player on the dealer's left and going clockwise. The dealer deals to themselves last.",
                "The rest of the deck stays face down and out of play, even if it holds scoring cards.",
            ], tactic: "Partners sit across from each other; the leftover deck is out of play, scoring cards included.")
            Text("East is dealing. Tap the seat that receives the first three cards.").font(.subheadline)
            VStack(spacing: 12) {
                tile(2)
                HStack { tile(1); Spacer(); tile(3) }
                tile(0)
            }
            Feedback(text: model.dealFeedback)
        }
    }

    private func tile(_ seat: Int) -> some View {
        let ring: Color? = model.dealPick == seat ? (seat == TutorialFixtures.firstDealt ? .correctRing : .incorrectRing) : nil
        return SeatTile(name: names[seat], detail: seat == 0 ? "that's you" : "6 cards",
                        badge: seat == TutorialFixtures.dealer ? "DEALER" : nil, ring: ring) { model.pickSeat(seat) }
    }
}
