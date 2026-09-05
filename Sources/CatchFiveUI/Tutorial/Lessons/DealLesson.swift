import CatchFive
import SwiftUI

struct DealLesson: View {
    @ObservedObject var model: TutorialModel
    private let names = Settings.defaultSeatNames

    var body: some View {
        VStack(spacing: 16) {
            LessonText(paragraphs: [
                "You and the player across from you are partners. West and East are the other team.",
                "The dealer gives everyone six cards, three at a time, starting on their left and going clockwise, themselves last.",
                "The rest of the deck stays face down and out of play, scoring cards included.",
            ], tactic: "Partners sit across from each other. Cards left in the deck never score.")
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
