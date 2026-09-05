import CatchFive
import SwiftUI

/// The home screen: who you are, who you are playing, and everything the app can do.
struct MainMenuView: View {
    @ObservedObject var model: GameModel
    let onPlay: () -> Void
    @StateObject private var tutorial: TutorialModel
    @State private var confirmNewMatch = false
    @State private var showTutorial = false
    @State private var showRules = false
    @State private var showHistory = false
    @State private var showSettings = false

    init(model: GameModel, onPlay: @escaping () -> Void) {
        _tutorial = StateObject(wrappedValue: model.makeTutorial())
        self.model = model
        self.onPlay = onPlay
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                welcome
                castArc
                if !model.settings.hasSeenRules {
                    Text("New here? Start with the tutorial.").font(.footnote).opacity(0.75)
                }
                buttons
            }
            .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
        .foregroundStyle(.ivory)
        .background(LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showTutorial, onDismiss: { model.markRulesSeen() }) { TutorialView(model: tutorial) { showTutorial = false } }
        .sheet(isPresented: $showRules) { RulesView { showRules = false } }
        .sheet(isPresented: $showHistory) { StatisticsView(stats: model.statistics, records: model.records) { showHistory = false } }
        .sheet(isPresented: $showSettings) { SettingsView(settings: $model.settings) }
        .confirmationDialog("Start over? This replaces your saved game.", isPresented: $confirmNewMatch) {
            Button("Start new match", role: .destructive) { model.newGame(); onPlay() }
        }
    }

    private var welcome: some View {
        HStack(spacing: 14) {
            PortraitView(portrait: model.settings.playerPortrait, size: 56)
            VStack(alignment: .leading, spacing: 2) {
                Text("CATCH 5").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.7)
                Text("Welcome back, \(model.settings.playerName ?? "friend")")
                    .font(.system(.title2, design: .serif).weight(.semibold)).lineLimit(2)
            }
            Spacer(minLength: 0)
        }
        .padding(.top, 24)
        .accessibilityElement(children: .combine)
    }

    /// The three opponents in a shallow arc, partner raised in the middle.
    private var castArc: some View {
        HStack(alignment: .top, spacing: 20) {
            ForEach(Array(Cast.opponents.enumerated()), id: \.offset) { index, character in
                VStack(spacing: 6) {
                    PortraitView(portrait: character.portrait, size: 56)
                    Text(model.seatNames[index + 1]).font(.subheadline.weight(.semibold))
                    Text(Cast.seatWords[index + 1]).font(.caption2).opacity(0.6)
                }
                .offset(y: index == 1 ? -14 : 0)
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 12)
    }

    private var buttons: some View {
        VStack(spacing: 12) {
            if model.matchInProgress {
                prominent("Continue", action: onPlay)
                plain("New match") { confirmNewMatch = true }
            } else {
                prominent("New match") {
                    if model.match.winner != nil { model.newGame() }
                    onPlay()
                }
            }
            plain("Tutorial") { showTutorial = true }
            plain("Rules") { showRules = true }
            plain("Match history") { showHistory = true }
            plain("Settings") { showSettings = true }
        }
    }

    private func prominent(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).font(.headline).frame(maxWidth: .infinity).frame(minHeight: 50) }
            .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
    }

    private func plain(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity).frame(minHeight: 44) }
            .buttonStyle(.bordered).tint(.ivory.opacity(0.8))
    }
}
