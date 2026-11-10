import CatchFive
import SwiftUI

struct TricksLesson: View {
    @ObservedObject var model: TutorialModel
    private let names = Settings.defaultSeatNames

    var body: some View {
        VStack(spacing: 16) {
            Text(model.trickPrompt).font(.headline).multilineTextAlignment(.center)
            table
            if model.trickPart == 0 { hand }
            Feedback(text: model.trickFeedback)
            
            DisclosureGroup("Why?") {
                LessonText(paragraphs: [
                    "The bid winner leads first, and must lead a trump if they hold one. Each player adds one card; those four cards are a hand. The winner takes them and leads next.",
                    "Follow the led suit if you can. If you cannot, play anything, trump included. The highest trump wins; with no trump, the highest card of the led suit.",
                ], tactic: "Never lead the five of trump. Lead your highest trump to pull the others out, and save the five for a hand your side is already winning.")
            }
        }
        .task(id: model.trickPick) {
            // After a correct pick, move on to the second part once the feedback has been read.
            guard model.trickPart == 0, let pick = model.trickPick, TutorialFixtures.trickLegalAnswers.contains(pick) else { return }
            try? await Task.sleep(for: .milliseconds(2500))
            guard !Task.isCancelled else { return }
            model.advanceTrickPart()
        }
    }

    private var table: some View {
        let plays = model.trickPart == 0 ? [TutorialFixtures.fullTrick[0]] : TutorialFixtures.fullTrick
        return VStack(spacing: 12) {
            Text(model.trickPart == 0 ? "ON THE TABLE · SPADES TRUMP" : "WHICH CARD WINS?").font(.caption2.monospaced()).tracking(2).opacity(0.6)
            HStack(spacing: 12) {
                ForEach(plays, id: \.card) { play in
                    VStack(spacing: 8) {
                        PickableCard(card: play.card, ring: model.trickPart == 1 && model.winnerPick == play.seat
                                     ? (play.seat == TutorialFixtures.trickWinnerAnswer ? .correctRing : .incorrectRing) : nil) {
                            if model.trickPart == 1 { model.pickWinner(play.seat) }
                        }
                        .accessibilityLabel("\(names[play.seat]) played the \(play.card.name)")
                        Text(names[play.seat]).font(.caption2)
                    }
                }
            }.frame(minHeight: 96)
        }.frame(maxWidth: .infinity).padding(.vertical, 20)
            // The trick lies on felt, as it does at the table.
            .foregroundStyle(.ivory)
            .background(Color.felt, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Theme.Paper.rule, lineWidth: 1.5))
    }

    private var hand: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("YOUR HAND").font(.caption.monospaced()).tracking(1)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(TutorialFixtures.trickHand, id: \.self) { card in
                        PickableCard(card: card, ring: model.trickPick == card
                                     ? (TutorialFixtures.trickLegalAnswers.contains(card) ? .correctRing : .incorrectRing) : nil) {
                            model.pickTrickCard(card)
                        }
                        .accessibilityLabel(card.name)
                    }
                }.padding(.bottom, 8)
            }
        }
    }
}
