import CatchFive
import SwiftUI

/// The pause card, shown over the dimmed table at launch and from the table's Home control: who you are,
/// then exactly three actions (spec R32). Continue game (until the match is won) is primary, New match asks
/// first, and Main menu keeps the match and goes to the menu, where Settings, the lessons, statistics and
/// the build explainer live.
struct WelcomeCard: View {
    @ObservedObject var model: GameModel
    let onPlay: () -> Void
    /// Leaves the table for the main menu with the match preserved.
    let onMenu: () -> Void
    @State private var confirmNewMatch = false

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

            if let context = model.resumeContext {
                Text(context).font(.footnote).opacity(0.8).frame(maxWidth: .infinity, alignment: .leading)
            }

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
                plain("Main menu", action: onMenu)
            }
        }
        .padding(22)
        .frame(maxWidth: 360)
        .background(Theme.Wood.inlay.opacity(0.96), in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(.ivory.opacity(0.18), lineWidth: 1))
        .shadow(color: .black.opacity(0.5), radius: 24, y: 12)
        .foregroundStyle(.ivory)
        .padding(24)
        .confirmationDialog("Start over? This replaces your saved game.", isPresented: $confirmNewMatch) {
            Button("Start new match", role: .destructive) { model.newGame(); onPlay() }
        }
    }

    private func prominent(_ label: String, action: @escaping () -> Void) -> some View {
        MenuButtons.prominent(label, action: action)
    }

    private func plain(_ label: String, action: @escaping () -> Void) -> some View {
        MenuButtons.plain(label, action: action)
    }
}

/// The menu's two buttons, shared by the pause card and the main menu: one gold primary per screen, and
/// bordered ivory for the rest.
enum MenuButtons {
    static func prominent(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).font(.headline).frame(maxWidth: .infinity).frame(minHeight: 48) }
            .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
    }

    static func plain(_ label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) { Text(label).frame(maxWidth: .infinity).frame(minHeight: 44) }
            .buttonStyle(.bordered).tint(.ivory.opacity(0.8))
    }
}

extension View {
    /// Full screen on the phone, where the reader wants the whole display; a sheet on the macOS test build.
    func fullScreenCoverOrSheet<Content: View>(isPresented: Binding<Bool>, @ViewBuilder content: @escaping () -> Content) -> some View {
        #if os(iOS)
        return fullScreenCover(isPresented: isPresented, content: content)
        #else
        return sheet(isPresented: isPresented, content: content)
        #endif
    }
}
