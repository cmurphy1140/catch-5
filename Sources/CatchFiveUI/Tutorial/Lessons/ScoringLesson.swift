import CatchFive
import SwiftUI

struct ScoringLesson: View {
    @ObservedObject var model: TutorialModel

    var body: some View {
        VStack(spacing: 16) {
            LessonText(paragraphs: [
                "Nine points a hand, all decided by what each team captured.",
                "High and Low: the highest and lowest trump played, 1 point each. The jack of trump: 1. The five of trump: 5.",
                "Game: 1 point for the higher count, where tens are 10, aces 4, kings 3, queens 2, jacks 1. A tie goes to the bidders.",
                "Bidders keep their points if they made the bid and lose the bid if not. The other team always keeps its points. First to 25 wins.",
            ], tactic: "The five outweighs everything else together. Feed it to your partner's winning card, and watch for an opponent forced to play it.")
            Text("Spades were trump and they bid 4. Assign each point to the team that earned it.").font(.subheadline).multilineTextAlignment(.center)
            pile("US", TutorialFixtures.usCaptured)
            pile("THEM", TutorialFixtures.themCaptured)
            VStack(spacing: 8) {
                ForEach(ScoreCategory.allCases, id: \.self) { category in
                    HStack {
                        Text(category == .five ? "Five · 5 points" : category.rawValue).font(.subheadline)
                        Spacer()
                        teamButton(category, 0, "Us")
                        teamButton(category, 1, "Them")
                    }
                    if let correct = model.scoringIsCorrect(category) {
                        Text(correct ? TutorialFixtures.scoringExplanations[category] ?? "" : "Not quite. Look at the cards each side captured.")
                            .font(.caption2).foregroundStyle(.ivory.opacity(0.85)).frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            Feedback(text: model.allScoringCorrect
                     ? "Hand points: us 2, them 7. They bid 4 and took 7, so they keep all 7. Scores go from 10–5 to 12–12."
                     : "")
        }
    }

    private func pile(_ title: String, _ cards: [Card]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(title) CAPTURED").font(.caption2.monospaced()).tracking(1).opacity(0.6)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) { ForEach(cards, id: \.self) { CardView(card: $0, width: Theme.Card.backWidth) } }
                    .padding(.bottom, 6)
            }
        }
    }

    private func teamButton(_ category: ScoreCategory, _ team: Int, _ label: String) -> some View {
        let picked = model.scoringPicks[category] == team
        return Button(label) { model.assign(category, to: team) }
            .buttonStyle(.bordered).tint(.ivory.opacity(0.8)).frame(minWidth: 64, minHeight: 44)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(picked ? (TutorialFixtures.scoringAnswers[category] == team ? Color.correctRing : .incorrectRing) : .clear, lineWidth: 3))
            .accessibilityLabel("\(category.rawValue) to \(label)")
    }
}
