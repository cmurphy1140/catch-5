import CatchFive
import SwiftUI

struct DealLesson: View {
    @ObservedObject var model: TutorialModel
    private let names = Settings.defaultSeatNames

    var body: some View {
        VStack(spacing: 12) {
            Text("East is dealing. Tap the seat that receives the first three cards.").font(.headline)
                .fixedSize(horizontal: false, vertical: true)
            // The four seats as they sit round a table, short enough that all four show on the play page's sheet.
            VStack(spacing: 8) {
                tile(2).frame(maxWidth: 200)
                HStack(spacing: 8) { tile(1); tile(3) }
                tile(0).frame(maxWidth: 200)
            }
            Feedback(text: model.dealFeedback)
            
            DisclosureGroup("Why?") {
                LessonText(paragraphs: [
                    "You and the player across from you are partners. West and East are the other team.",
                    "The dealer gives everyone six cards, three at a time, starting on their left and going clockwise, themselves last.",
                    "The rest of the deck stays face down and out of play, scoring cards included.",
                ], tactic: "Partners sit across from each other. Cards left in the deck never score.")
            }
        }
    }

    private func tile(_ seat: Int) -> some View {
        let ring: Color? = model.dealPick == seat ? (seat == TutorialFixtures.firstDealt ? .correctRing : .incorrectRing) : nil
        let detail = seat == 0 ? "that's you" : "\(Cast.seatWords[seat]) · 6 cards"
        return SeatTile(name: names[seat], detail: detail,
                        badge: seat == TutorialFixtures.dealer ? "DEALER" : nil, ring: ring,
                        portrait: Cast.opponent(at: seat)?.portrait, figure: seat == 0 ? nil : SeatArt.image(seat: seat, opponents: .friends), compact: true) { model.pickSeat(seat) }
    }
}
