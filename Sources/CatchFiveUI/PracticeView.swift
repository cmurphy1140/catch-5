import CatchFive
import SwiftUI

struct PracticeSetupView: View {
    let names: [String]
    @State private var configuration: PracticeConfiguration
    let replayDescription: String?
    let onStart: (PracticeConfiguration) -> Void
    let onClose: () -> Void

    init(names: [String], configuration: PracticeConfiguration, replayDescription: String?,
         onStart: @escaping (PracticeConfiguration) -> Void, onClose: @escaping () -> Void) {
        self.names = names
        _configuration = State(initialValue: configuration)
        self.replayDescription = replayDescription
        self.onStart = onStart
        self.onClose = onClose
    }

    var body: some View {
        LearningPage(title: "Practice", onClose: onClose) {
            Text("Try a hand, keep the family score.")
                .font(.system(.title2, design: .serif).weight(.bold))
                .accessibilityAddTraits(.isHeader)
            Text("Practice starts at zero in its own game. Your real game, saved hands and statistics stay as they are.")
            if let replayDescription {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Original deal").font(.headline)
                    Text(replayDescription)
                }
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Your starting hand").font(.headline)
                    Picker("Starting deal", selection: $configuration.deal) {
                        ForEach(PracticeDeal.allCases) { deal in Text(deal.title).tag(deal) }
                    }
                    .pickerStyle(.menu).frame(minHeight: 44)
                    Text("Fresh is shuffled. The two sample hands let you revisit the same opening.")
                        .font(.footnote).foregroundStyle(Theme.Paper.ink.opacity(0.75))
                }
            }
            Divider().overlay(Theme.Paper.rule)
            Text("The other seats").font(.headline).accessibilityAddTraits(.isHeader)
            difficulty(seat: 1, role: "Left opponent", selection: $configuration.left)
            difficulty(seat: 2, role: "Your partner", selection: $configuration.partner)
            difficulty(seat: 3, role: "Right opponent", selection: $configuration.right)
            Button("Start practice") { onStart(configuration) }.buttonStyle(PaperButtonStyle())
        }
    }

    private func difficulty(seat: Int, role: String, selection: Binding<Difficulty>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(names.indices.contains(seat) ? names[seat] : "Seat \(seat + 1)") · \(role)")
                .font(.system(.headline, design: .serif))
            PaperSwitch(options: [("Easy", Difficulty.easy), ("Standard", Difficulty.standard)], selection: selection)
                .accessibilityLabel("\(role) difficulty")
        }
    }
}

struct PracticeTableView: View {
    @ObservedObject var model: GameModel
    let onNewDeal: () -> Void
    let onClose: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Text("Practice").font(.system(.headline, design: .serif))
                    Spacer(minLength: 0)
                    controls
                }
                VStack(alignment: .leading, spacing: 0) {
                    Text("Practice").font(.system(.headline, design: .serif))
                    HStack { controls }
                }
            }
            .padding(.horizontal, 12)
            .foregroundStyle(.ivory)
            .background(Theme.Wood.header)
            if model.isPractice {
                TableView(model: model, onLeave: onClose, onHome: onClose)
                    .id(ObjectIdentifier(model))
            } else {
                Text("Practice could not be opened. Your real game is safe.")
                    .padding().frame(maxWidth: .infinity, maxHeight: .infinity)
                    .foregroundStyle(.ivory).background(Theme.Wood.header)
            }
        }
        #if os(iOS)
        .navigationBarBackButtonHidden()
        .toolbar(.hidden, for: .navigationBar)
        #endif
    }

    private var controls: some View {
        Group {
            Button("New deal", action: onNewDeal).accessibilityLabel("New practice deal")
                .frame(minHeight: 44)
            Button("Leave practice", action: onClose).frame(minHeight: 44)
        }
        .buttonStyle(.plain).font(.subheadline.weight(.semibold))
    }
}
