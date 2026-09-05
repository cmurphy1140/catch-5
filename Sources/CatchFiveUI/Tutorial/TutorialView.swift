import CatchFive
import SwiftUI

/// The five-lesson "How to play" sheet. Layout, copy and exercises follow docs/tutorial-spec.md.
struct TutorialView: View {
    @ObservedObject var model: TutorialModel
    let onDismiss: () -> Void
    @State private var showRules = false
    @State private var showExplainer = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    header
                    pills
                    lesson
                        .padding(16)
                        .background(Theme.Wood.inlay.opacity(0.6), in: RoundedRectangle(cornerRadius: 16))
                    footer
                }
                .padding(20).frame(maxWidth: 640).frame(maxWidth: .infinity)
            }
            .foregroundStyle(.ivory)
            .background(WoodGrainView().ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu("More") {
                        Button("Full rules") { showRules = true }
                        Button("How Catch 5 is built") { showExplainer = true }
                    }
                }
                ToolbarItem(placement: .confirmationAction) { Button("Done", action: onDismiss) }
            }
            .sheet(isPresented: $showRules) { RulesView { showRules = false } }
            #if canImport(UIKit)
            .sheet(isPresented: $showExplainer) { ExplainerView { showExplainer = false } }
            #endif
        }
        .preferredColorScheme(.dark)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("CATCH 5").font(.system(.largeTitle, design: .serif).weight(.bold))
            Text("HOW TO PLAY · LESSON \(model.lesson + 1) OF \(TutorialModel.lessonCount)")
                .font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1)
        }.frame(maxWidth: .infinity, alignment: .leading)
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
                            .background(index == model.lesson ? .gold.opacity(0.15) : Theme.Wood.inlay.opacity(0.5), in: Capsule())
                            .overlay(Capsule().stroke(index == model.lesson ? .gold : .white.opacity(0.1)))
                        }.buttonStyle(.plain).foregroundStyle(index == model.lesson ? .gold : .ivory)
                        .accessibilityLabel("Lesson \(index + 1), \(TutorialModel.titles[index])\(model.completed.contains(index) ? ", complete" : "")")
                    }
                }
            }
            Text("\(model.completed.count) / \(TutorialModel.lessonCount) complete").font(.caption2.monospaced()).opacity(0.6)
        }
    }

    @ViewBuilder private var lesson: some View {
        switch model.lesson {
        case 0: DealLesson(model: model)
        case 1: BiddingLesson(model: model)
        case 2: TrumpLesson(model: model)
        case 3: TricksLesson(model: model)
        default: ScoringLesson(model: model)
        }
    }

    private var footer: some View {
        HStack {
            Button("Back") { model.back() }.buttonStyle(.bordered).tint(.ivory.opacity(0.8)).disabled(model.lesson == 0)
            Spacer()
            Button(model.isLastLesson ? "Finish" : "Next lesson") { if model.isLastLesson { onDismiss() } else { model.next() } }
                .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
        }
    }
}

// MARK: - Shared pieces

/// Rules paragraph list followed by one tactic, styled like the table's hint panel.
struct LessonText: View {
    let paragraphs: [String]
    let tactic: String
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(paragraphs, id: \.self) { Text($0).font(.body) }
            Text("Tactic. \(tactic)")
                .font(.footnote).foregroundStyle(.ivory.opacity(0.9))
                .padding(12).frame(maxWidth: .infinity, alignment: .leading)
                .background(.ivory.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(.ivory.opacity(0.25)))
        }
    }
}

/// Gold feedback text with reserved height so the layout does not jump.
struct Feedback: View {
    let text: String
    var body: some View {
        Text(text).font(.footnote).foregroundStyle(.ivory.opacity(0.85)).multilineTextAlignment(.center)
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
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Text(name).font(.subheadline.weight(.semibold))
                Text(detail).font(.caption2).opacity(0.65)
                if let badge { Text(badge).font(.system(.caption2, design: .monospaced)).foregroundStyle(.gold) }
            }
            .padding(12).frame(minWidth: 80, minHeight: 44)
            .background(Theme.Wood.inlay.opacity(0.5), in: RoundedRectangle(cornerRadius: 12))
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(ring ?? .clear, lineWidth: 3))
        }.buttonStyle(.plain).foregroundStyle(.ivory)
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
    static var correctRing: Color { .gold }
    static var incorrectRing: Color { .white.opacity(0.6) }
}
