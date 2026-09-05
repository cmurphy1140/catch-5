import CatchFive
import SwiftUI

struct TrumpLesson: View {
    @ObservedObject var model: TutorialModel

    var body: some View {
        let correct = model.trumpPick == TutorialFixtures.trumpAnswer
        VStack(spacing: 16) {
            LessonText(paragraphs: [
                "The bid winner names a suit as trump. Any trump beats any card of another suit.",
                "Everyone then throws away their non-trump cards and draws back to six from the deck. The new cards can be anything, trumps included.",
            ], tactic: "Name the suit where you hold the most cards and the highest. Three trumps to the ace is strong; a lone king is not.")
            Text("You won the bid at 4. Tap the suit to name as trump.").font(.subheadline)
            HStack(spacing: 8) {
                ForEach(model.showRefill && correct ? TutorialFixtures.refilledHand : TutorialFixtures.biddingHand, id: \.self) { card in
                    let fresh = model.showRefill && correct && !TutorialFixtures.biddingHand.contains(card)
                    CardView(card: card)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(fresh ? Color.ivory : .clear, lineWidth: 3))
                        .opacity(correct && !model.showRefill && card.suit != .spades ? 0.35 : 1)
                }
            }
            HStack {
                ForEach(Suit.allCases, id: \.self) { suit in
                    Button(suit.glyph) { model.showRefill = false; model.chooseTrump(suit) }
                        .buttonStyle(.bordered).tint(.ivory.opacity(0.8)).frame(minHeight: 44)
                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(model.trumpPick == suit ? (suit == TutorialFixtures.trumpAnswer ? Color.correctRing : .incorrectRing) : .clear, lineWidth: 3))
                        .accessibilityLabel(suit.rawValue)
                }
            }
            if correct {
                Toggle("Discard and refill", isOn: $model.showRefill).tint(.ivory.opacity(0.6)).font(.footnote)
            }
            Feedback(text: model.showRefill && correct ? "Three new cards, ringed: one more spade and two side cards drawn from the deck. Your three non-spades are gone." : model.trumpFeedback)
        }
    }
}
