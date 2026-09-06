import CatchFive
import SwiftUI

/// The main menu (spec R31): who is playing, where the saved match stands, and every destination that is
/// not the table itself. Continue game leads back to the match untouched; New match replaces it after a
/// word of warning; How to play opens the lessons. Settings, Statistics and the build explainer wait in a
/// hamburger menu in the top-right corner, one tap from here in every mode (spec R29), as a bare glyph
/// with no plate (spec R19).
struct MainMenuView: View {
    @ObservedObject var model: GameModel
    @ObservedObject var tutorial: TutorialModel
    /// Continue or a fresh deal: the table takes over.
    let onPlay: () -> Void
    @State private var confirmNewMatch = false
    @State private var showSettings = false
    @State private var showTutorial = false
    @State private var showStatistics = false
    @State private var showExplainer = false

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("CATCH 5").font(.system(.largeTitle, design: .serif).weight(.bold))
                    Text("MAIN MENU").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.7)
                }
                .padding(.top, 40)

                HStack(spacing: 14) {
                    PortraitView(portrait: model.settings.playerPortrait, size: 56)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(model.settings.playerName ?? "friend")
                            .font(.system(.title3, design: .serif).weight(.semibold)).lineLimit(1)
                        Text(model.settings.difficulty == .easy ? "Easy opponents" : "Standard opponents")
                            .font(.footnote).opacity(0.75)
                        if let context = model.resumeContext {
                            Text(context).font(.footnote).opacity(0.75)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(16)
                .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                .accessibilityElement(children: .combine)

                VStack(spacing: 10) {
                    if model.match.winner == nil {
                        MenuButtons.prominent("Continue game", action: onPlay)
                        MenuButtons.plain("New match") {
                            if model.matchInProgress { confirmNewMatch = true } else { model.newGame(); onPlay() }
                        }
                    } else {
                        MenuButtons.prominent("New match") { model.newGame(); onPlay() }
                    }
                    MenuButtons.plain("How to play") { showTutorial = true }
                }
            }
            .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
        .overlay(alignment: .topTrailing) {
            Menu {
                Button("Settings", systemImage: "gearshape") { showSettings = true }
                Button("Statistics", systemImage: "chart.bar") { showStatistics = true }
                Button("How Catch 5 is built", systemImage: "doc.text.magnifyingglass") { showExplainer = true }
            } label: {
                Image(systemName: "line.3.horizontal").font(.title2.weight(.medium))
                    .shadow(color: .black.opacity(0.45), radius: 1.5, y: 1)
                    .frame(width: Theme.Table.statusButtonHitSize, height: Theme.Table.statusButtonHitSize)
                    .contentShape(Rectangle())
            }
            .tint(.ivory)
            .accessibilityLabel("Menu")
            .padding(.trailing, 12).padding(.top, 4)
        }
        .foregroundStyle(.ivory)
        .background(LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .sheet(isPresented: $showSettings) { SettingsView(settings: $model.settings) }
        .sheet(isPresented: $showTutorial, onDismiss: { model.markRulesSeen() }) { TutorialView(model: tutorial) { showTutorial = false } }
        .sheet(isPresented: $showStatistics) { StatisticsView(stats: model.statistics, records: model.records) { showStatistics = false } }
        .fullScreenCoverOrSheet(isPresented: $showExplainer) { ExplainerView { showExplainer = false } }
        .confirmationDialog("Start over? This replaces your saved game.", isPresented: $confirmNewMatch) {
            Button("Start new match", role: .destructive) { model.newGame(); onPlay() }
        }
    }
}
