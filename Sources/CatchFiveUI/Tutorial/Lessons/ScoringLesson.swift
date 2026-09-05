import CatchFive
import SwiftUI

struct ScoringLesson: View {
    @ObservedObject var model: TutorialModel

    var body: some View {
        VStack(spacing: 16) {
            LessonText(paragraphs: [
                "Nine points are on offer each hand, all decided by the cards each team captured. High and Low go to whoever took the highest and lowest trump actually played. The jack of trump is 1 point, and the five of trump is 5.",
                "Game is 1 point for the team whose captured cards add up to more: tens count 10, aces 4, kings 3, queens 2, jacks 1. A tie goes to the bidders.",
                "The bidders keep their points if they made the bid and lose the bid if they fell short. The other team always keeps its points. First to 25 wins.",
            ], tactic: "The five is worth more than everything else put together. Give it to your partner's winning card; watch for the moment an opponent is forced to play it.")
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
                            .font(.caption2).foregroundStyle(.gold).frame(maxWidth: .infinity, alignment: .leading)
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
                HStack(spacing: 6) { ForEach(cards, id: \.self) { CardView(card: $0).scaleEffect(0.85).frame(width: 42, height: 62) } }
                    .padding(.bottom, 6)
            }
        }
    }

    private func teamButton(_ category: ScoreCategory, _ team: Int, _ label: String) -> some View {
        let picked = model.scoringPicks[category] == team
        return Button(label) { model.assign(category, to: team) }
            .buttonStyle(.bordered).tint(.gold).frame(minWidth: 64, minHeight: 44)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(picked ? (TutorialFixtures.scoringAnswers[category] == team ? Color.correctRing : .incorrectRing) : .clear, lineWidth: 3))
            .accessibilityLabel("\(category.rawValue) to \(label)")
    }
}
