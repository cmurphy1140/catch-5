import CatchFive
import SwiftUI

/// The five-lesson "How to play" sheet. Layout, copy and exercises follow docs/tutorial-spec.md.
struct TutorialView: View {
    @ObservedObject var model: TutorialModel
    /// Opened from the new player's intro: the toolbar says Skip and the last lesson ends with New game.
    var isIntro = false
    let onDismiss: () -> Void
    @State private var showRules = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    pills
                    // The lesson is one ivory reading card (D107, D111): its number, its name, the exercise, then the way on.
                    VStack(spacing: 16) {
                        header
                        lesson
                        footer
                    }
                    .padding(18)
                    .foregroundStyle(Theme.Paper.ink)
                    .tint(Theme.Paper.green)
                    .paperCard()
                    .environment(\.colorScheme, .light)
                }
                .padding(14).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .foregroundStyle(.ivory)
            .background(WoodGrainView().overlay(.black.opacity(0.5)).ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Full rules") { showRules = true } }
                ToolbarItem(placement: .confirmationAction) { Button(isIntro ? "Skip" : "Done", action: onDismiss) }
            }
            .sheet(isPresented: $showRules) { RulesView { showRules = false } }
            .onAppear { if ["rules", "signoff"].contains(ScreenshotStage.name ?? "") { showRules = true } }
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(spacing: 6) {
            RuledLine {
                Text("LESSON \(model.lesson + 1) OF \(TutorialModel.lessonCount)")
                    .font(.caption.weight(.semibold)).tracking(2).foregroundStyle(Theme.Paper.green)
            }
            Text(TutorialModel.titles[model.lesson]).font(.system(.largeTitle, design: .serif).weight(.bold))
                .accessibilityAddTraits(.isHeader)
        }.frame(maxWidth: .infinity)
    }

    private var pills: some View {
        VStack(spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(0..<TutorialModel.lessonCount, id: \.self) { index in
                        Button { model.lesson = index } label: {
                            HStack(spacing: 6) {
                                if model.completed.contains(index) { Image(systemName: "checkmark").font(.caption2) }
                                Text("\(index + 1) · \(TutorialModel.titles[index])").font(.footnote.weight(.semibold))
                            }
                            .padding(.horizontal, 14).frame(height: 44)
                            .background(index == model.lesson ? .ivory : .clear, in: Capsule())
                            .overlay(Capsule().stroke(.gold.opacity(index == model.lesson ? 1 : 0.55), lineWidth: index == model.lesson ? 2 : 1))
                        }.buttonStyle(.plain).foregroundStyle(index == model.lesson ? Theme.Paper.green : .ivory)
                        .accessibilityLabel("Lesson \(index + 1), \(TutorialModel.titles[index])\(model.completed.contains(index) ? ", complete" : "")")
                    }
                }
            }
            Text("\(model.completed.count) / \(TutorialModel.lessonCount) complete").font(.caption2.monospaced()).opacity(0.6)
        }
    }

    private var lesson: some View { TutorialLesson(model: model) }

    private var footer: some View {
        HStack(spacing: 10) {
            if model.lesson > 0 {
                Button("Back") { model.back() }.buttonStyle(PaperSecondaryButtonStyle()).frame(maxWidth: 110)
            }
            Button(model.isLastLesson ? (isIntro ? "New game" : "Finish") : "Next lesson") { if model.isLastLesson { onDismiss() } else { model.next() } }
                .buttonStyle(PaperButtonStyle())
        }
    }
}

// MARK: - Shared pieces

/// The lesson the model is on; the tutorial sheet and the play page's fixed sheet (D133) both show it.
struct TutorialLesson: View {
    @ObservedObject var model: TutorialModel

    var body: some View {
        switch model.lesson {
        case 0: DealLesson(model: model)
        case 1: BiddingLesson(model: model)
        case 2: TrumpLesson(model: model)
        case 3: TricksLesson(model: model)
        default: ScoringLesson(model: model)
        }
    }
}

/// Rules paragraph list followed by one tactic, styled like the table's hint panel.
struct LessonText: View {
    let paragraphs: [String]
    let tactic: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(paragraphs, id: \.self) { Text($0).font(.body).lineSpacing(2).fixedSize(horizontal: false, vertical: true) }
            Text("Tactic. \(tactic)")
                .font(.footnote)
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(Theme.Paper.wash, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Theme.Paper.rule))
        }
    }
}

/// Green feedback text with reserved height so the layout does not jump.
struct Feedback: View {
    let text: String
    var body: some View {
        Text(text).font(.callout.weight(.medium)).foregroundStyle(Theme.Paper.green).multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 60, alignment: .top)
            .accessibilityLabel(text.isEmpty ? "" : "Feedback: \(text)")
    }
}

/// A tappable seat tile matching the table's opponent tiles.
struct SeatTile: View {
    let name: String
    let detail: String
    var badge: String? = nil
    var ring: Color? = nil
    var portrait: Portrait? = nil
    let action: () -> Void
    /// Every label stays on one line and shrinks a little rather than wrapping, so three tiles fit a row
    /// at the boosted text size.
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                if let portrait { PortraitView(portrait: portrait, size: Theme.Table.tutorialPortraitSize) }
                Text(name).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption).opacity(0.7)
                if let badge { Text(badge).font(.system(.caption2, design: .monospaced)).foregroundStyle(Color.suitRed) }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 8).padding(.vertical, 10)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(Theme.Paper.tan.opacity(0.6), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ring ?? Theme.Paper.rule.opacity(0.6), lineWidth: ring == nil ? 1 : 3))
        }.buttonStyle(.plain)
    }
}

/// A card the learner can tap, with the spec's selection rings.
struct PickableCard: View {
    let card: Card
    var ring: Color? = nil
    var dimmed = false
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            CardView(card: card)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(ring ?? .clear, lineWidth: 3))
                .opacity(dimmed ? 0.35 : 1)
        }.buttonStyle(.plain).frame(minWidth: 44, minHeight: 44)
    }
}

extension Color {
    /// On ivory: green for right, the opponents' oxblood for not quite.
    static var correctRing: Color { Theme.Paper.green }
    static var incorrectRing: Color { Theme.Team.theirRim }
}

/// A choice in a lesson (a bid, a suit, a side): an ivory tile with a gold edge and a green serif label.
struct PaperTileStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        configuration.label
            .font(.system(.title3, design: .serif).weight(.bold)).lineLimit(1).minimumScaleFactor(0.6)
            .foregroundStyle(Theme.Paper.green)
            .padding(.horizontal, 8).frame(maxWidth: .infinity, minHeight: 44)
            .background(shape.fill(.ivory).shadow(color: .black.opacity(0.2), radius: 2, y: 1))
            .overlay(shape.stroke(Theme.Paper.rule, lineWidth: 1))
            .opacity(configuration.isPressed ? 0.7 : 1)
    }
}
