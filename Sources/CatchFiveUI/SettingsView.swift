import CatchFive
import SwiftUI

/// Settings on ivory paper under the cloth band (D107, D181): difficulty, your name and face, the opponents'
/// names, haptics and, from the main menu, starting over as a new player (D108), each under a suit, with gold rules between.
struct SettingsView: View {
    @Binding var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var nameDraft = ""
    /// Starts over as a new player; nil where that is not offered (at the table, mid-game).
    var onNewPlayer: (() -> Void)?
    @State private var confirmNewPlayer = false

    var body: some View {
        ClothPage(title: "Settings", onDone: { dismiss() }, spacing: 14) {
            heading("♠", "Difficulty")
            PaperSwitch(options: [("Easy", Difficulty.easy), ("Standard", Difficulty.standard)], selection: $settings.difficulty, ticks: true)
            Text("Easy players use the original strategy and lose about two matches in three to Standard. Hints always use Standard.")
                .font(.subheadline).fixedSize(horizontal: false, vertical: true)
            rule
            heading("♥", "Table")
            // One table now (D158); the only choice is the cloth, shown as the two cloths themselves (D181).
            HStack(alignment: .top, spacing: 0) {
                FeltSwatch(title: "Charcoal felt", cloth: .charcoal, chosen: settings.tableColours != .green) { settings.tableColours = .charcoal }
                FeltSwatch(title: "Green felt", cloth: .green, chosen: settings.tableColours == .green) { settings.tableColours = .green }
            }
            rule
            heading("♦", "You")
            // A draft, so spaces and clearing work while typing; each non-blank edit is committed.
            VStack(spacing: 0) {
                field(TextField("Your name", text: $nameDraft)
                    .onAppear { nameDraft = settings.playerName ?? settings.seatNames[0] }
                    .onChange(of: nameDraft) { _, new in settings.setPlayerName(new) })
                Rectangle().fill(Theme.Paper.green).frame(height: 1.5).accessibilityHidden(true)
            }
            HStack(spacing: 0) {
                ForEach(Array(Cast.playerChoices.enumerated()), id: \.offset) { index, choice in
                    let chosen = settings.playerPortrait == choice
                    Button { settings.playerPortrait = choice } label: {
                        PortraitView(portrait: choice, size: 60)
                            .padding(4)
                            .overlay(Circle().stroke(Theme.Paper.green, lineWidth: chosen ? 3 : 0))
                            .overlay(alignment: .bottomTrailing) {
                                if chosen {
                                    Image(systemName: "checkmark.circle.fill").font(.title3)
                                        .foregroundStyle(.ivory, Theme.Paper.green)
                                }
                            }
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Face \(index + 1)")
                    .accessibilityAddTraits(chosen ? .isSelected : [])
                }
            }
            DisclosureGroup("Make your own face") {
                FaceBuilder(portrait: $settings.playerPortrait).padding(.top, 8)
            }
            .font(.title3.weight(.medium)).tint(Theme.Paper.green)
            rule
            heading("♣", "Opponents")
            PaperSwitch(options: [("Friends", Settings.Opponents.friends), ("Family", Settings.Opponents.family)],
                        selection: Binding(get: { settings.opponents }, set: { settings.seat($0) }), ticks: true)
            // The roster: each figure beside its name, a hairline between, no box round the three (D181).
            VStack(spacing: 0) {
                ForEach(1..<4, id: \.self) { seat in
                    HStack(spacing: 16) {
                        Group {
                            if let art = SeatArt.image(seat: seat, opponents: settings.opponents) {
                                art.resizable().scaledToFit()
                            } else if let character = Cast.opponent(at: seat) {
                                PortraitView(portrait: character.portrait, size: 52)
                            }
                        }
                        .frame(width: 68, height: 60, alignment: .bottom)
                        field(TextField(settings.opponents.names[seat], text: Binding(
                            get: { settings.seatNames[seat] },
                            set: { settings.seatNames[seat] = $0.trimmingCharacters(in: .whitespaces).isEmpty ? settings.opponents.names[seat] : $0 }))
                            .font(.system(.title2, design: .serif).weight(.semibold)))
                    }
                    .padding(.vertical, 6)
                    if seat < 3 { PageRule(weight: 1).opacity(0.6) }
                }
            }
            rule
            Toggle(isOn: $settings.haptics) {
                Label("Haptics on every hand", systemImage: "iphone.radiowaves.left.and.right").font(.title3)
            }
            .tint(Theme.Paper.green)
            if onNewPlayer != nil {
                rule
                Button { confirmNewPlayer = true } label: {
                    Label("Start over as a new player", systemImage: "person.crop.circle.badge.plus").font(.title3.weight(.medium))
                        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading).contentShape(Rectangle())
                }
                .buttonStyle(.plain).foregroundStyle(Theme.Team.theirRim)
                .accessibilityHint("Clears your name, saved game and statistics; asks first")
            }
        }
        // An alert, as New game uses (D57), so Cancel is always there.
        .alert("Start over as a new player?", isPresented: $confirmNewPlayer) {
            Button("Start over", role: .destructive) { onNewPlayer?() }
            Button("Cancel", role: .cancel) {}
        } message: { Text("This clears your name and face, your saved game and your statistics. It cannot be undone.") }
    }

    private var rule: some View { PageRule() }

    /// A section's name in the display serif, behind its suit.
    private func heading(_ suit: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text(suit).foregroundStyle(Color.suitRed).accessibilityHidden(true)
            Text(title).accessibilityAddTraits(.isHeader)
        }
        .font(.system(.title, design: .serif).weight(.bold))
    }

    /// A name to type over, with a pencil saying so.
    private func field(_ text: some View) -> some View {
        HStack {
            text.font(.title3)
            Image(systemName: "pencil").font(.title3.weight(.semibold)).foregroundStyle(Theme.Paper.green).accessibilityHidden(true)
        }
        .frame(minHeight: 48)
    }
}
