import SwiftUI
import CatchFive

/// New game's setup (D180), in place of the two-way question (`NewMatchCard`): the mode at the top, and under it
/// only what that mode needs. Solo chooses who sits opposite and how well they play; pass and play names the four
/// who share the phone, as two teams. One button deals.
struct NewGameSetup: View {
    @Binding var settings: Settings
    let replacesSavedGame: Bool
    let onStart: (PlayMode) -> Void
    let onCancel: () -> Void

    @State private var mode: PlayMode
    /// The four names as typed, in seat order; partners are seats 0 and 2, and 1 and 3.
    @State private var names: [String]

    init(settings: Binding<Settings>, mode: PlayMode, replacesSavedGame: Bool, onStart: @escaping (PlayMode) -> Void, onCancel: @escaping () -> Void) {
        _settings = settings
        self.replacesSavedGame = replacesSavedGame
        self.onStart = onStart
        self.onCancel = onCancel
        _mode = State(initialValue: mode)
        _names = State(initialValue: settings.wrappedValue.names(passAndPlay: true))
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea().onTapGesture(perform: onCancel).accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 14) {
                Text(NewMatchCard.title(replacesSavedGame: replacesSavedGame))
                    .font(.system(.largeTitle, design: .serif).weight(.bold)).accessibilityAddTraits(.isHeader)
                if replacesSavedGame {
                    Label(NewMatchCard.warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.body.weight(.semibold)).foregroundStyle(Theme.Team.theirRim)
                }
                PaperSwitch(options: [("Solo", PlayMode.solo), ("Pass and play", PlayMode.passAndPlay)], selection: $mode, ticks: true)
                Group {
                    if mode == .solo { solo } else { passAndPlay }
                }
                .transition(.opacity)
                Button("Deal") { start() }.buttonStyle(PaperButtonStyle()).keyboardShortcut(.defaultAction)
                Button(action: onCancel) {
                    Text("Cancel").font(.system(.title3, design: .serif).weight(.semibold))
                        .frame(maxWidth: .infinity, minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain).keyboardShortcut(.cancelAction)
            }
            .animation(Theme.Motion.overlay, value: mode)
            .padding(20)
            .foregroundStyle(Theme.Paper.ink)
            .tint(Theme.Paper.green)
            .paperCard()
            .environment(\.colorScheme, .light)
            .padding(.horizontal, 24)
            .frame(maxWidth: 460)
            .accessibilityElement(children: .contain)
            .accessibilityAddTraits(.isModal)
        }
    }

    private func start() {
        if mode == .passAndPlay {
            settings.passAndPlayNames = Settings.passAndPlayNames(typed: names, fallback: settings.names(passAndPlay: true))
        }
        onStart(mode)
    }

    private func label(_ text: String) -> some View {
        Text(text).font(.system(.headline, design: .serif)).accessibilityAddTraits(.isHeader)
    }

    /// Solo: who the three computer players are, and how well they play.
    private var solo: some View {
        VStack(alignment: .leading, spacing: 10) {
            label("Across the table")
            PaperSwitch(options: [("Friends", Settings.Opponents.friends), ("Family", Settings.Opponents.family)],
                        selection: Binding(get: { settings.opponents }, set: { settings.seat($0) }), ticks: true)
            Text(settings.opponents.label).font(.subheadline).opacity(0.75)
            label("How they play").padding(.top, 4)
            PaperSwitch(options: [("Easy", Difficulty.easy), ("Standard", Difficulty.standard)], selection: $settings.difficulty, ticks: true)
            Text(settings.difficulty == .easy ? "They lose about two matches in three to Standard." : "They bid and play to win.")
                .font(.subheadline).opacity(0.75).fixedSize(horizontal: false, vertical: true)
        }
    }

    /// Pass and play: the four names, as the two teams. Partners sit across from each other.
    private var passAndPlay: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Four players share this phone. Partners sit across from each other.")
                .font(.subheadline).opacity(0.75).fixedSize(horizontal: false, vertical: true)
            team("One team", seats: (0, 2))
            team("The other team", seats: (1, 3))
        }
    }

    private func team(_ title: String, seats: (Int, Int)) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            label(title)
            HStack(spacing: 10) {
                name(seats.0)
                Text("and").font(.subheadline).opacity(0.6).accessibilityHidden(true)
                name(seats.1)
            }
        }
    }

    /// One name to type over: on the paper with a rule under it, and no box.
    private func name(_ seat: Int) -> some View {
        TextField("Player \(seat + 1)", text: Binding(get: { names.indices.contains(seat) ? names[seat] : "" },
                                                      set: { if names.indices.contains(seat) { names[seat] = $0 } }))
            .font(.title3).submitLabel(.done)
            .frame(minHeight: 44)
            .overlay(alignment: .bottom) { Rectangle().fill(Theme.Paper.green.opacity(0.6)).frame(height: 1.5) }
            .accessibilityLabel("Player \(seat + 1)")
    }
}
