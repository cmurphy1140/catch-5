import CatchFive
import SwiftUI

/// The returning player's card, shown over the dimmed table at launch and from the table's chevron:
/// who you are, then Continue game (until the match is won), New match and Settings. No history, no lessons;
/// those stay in the table's gear menu.
struct WelcomeCard: View {
    @ObservedObject var model: GameModel
    let onPlay: () -> Void
    @State private var confirmNewMatch = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 14) {
                PortraitView(portrait: model.settings.playerPortrait, size: 48)
                VStack(alignment: .leading, spacing: 2) {
                    Text("CATCH 5").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.7)
                    Text("Welcome back, \(model.settings.playerName ?? "friend")")
                        .font(.system(.title3, design: .serif).weight(.semibold)).lineLimit(2)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            VStack(spacing: 10) {
                if model.match.winner == nil {
                    // A dealt hand is a game to return to even before the first bid.
                    prominent("Continue game", action: onPlay)
                    plain("New match") {
                        if model.matchInProgress { confirmNewMatch = true } else { model.newGame(); onPlay() }
                    }
                } else {
                    prominent("New match") { model.newGame(); onPlay() }
                }
                plain("Settings") { showSettings = true }
            }
        }
        .padding(22)
        .frame(maxWidth: 360)
        .background(Theme.Wood.inlay.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.ivory.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
        .foregroundStyle(.ivory)
        .padding(24)
        .sheet(isPresented: $showSettings) { SettingsView(settings: $model.settings) }
        .confirmationDialog("Start over? This replaces your saved game.", isPresented: $confirmNewMatch) {
            Button("Start new match", role: .destructive) { model.newGame(); onPlay() }
        }
    }

    private func prominent(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).font(.headline).frame(maxWidth: .infinity).frame(minHeight: 48) }
            .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
    }

    private func plain(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity).frame(minHeight: 44) }
            .buttonStyle(.bordered).tint(.ivory.opacity(0.8))
    }
}
