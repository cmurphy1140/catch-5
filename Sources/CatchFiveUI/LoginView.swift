import CatchFive
import SwiftUI

/// Setting up your player, once. This is a local profile, not an account: nothing here talks to a network; "New match" writes Settings and opens the intro.
struct LoginView: View {
    @ObservedObject var model: GameModel
    let onDone: () -> Void
    @State private var name = ""
    @State private var portrait = Cast.defaultPlayerPortrait
    @State private var difficulty = Difficulty.standard
    @FocusState private var nameFocused: Bool

    private var trimmed: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var body: some View {
        ScrollView {
            VStack(spacing: 18) {
                VStack(spacing: 2) {
                    Text("Catch 5").font(.system(size: 44, weight: .bold, design: .serif))
                    Text("Set up your player").font(.system(.title3, design: .serif)).opacity(0.85)
                }
                .foregroundStyle(.ivory)
                .padding(.top, 12)
                .accessibilityElement(children: .combine).accessibilityAddTraits(.isHeader)

                // The same paper and the same parts as Settings (D181), so the first page looks like the rest (D191).
                VStack(alignment: .leading, spacing: 14) {
                    heading("♦", "Your name")
                    VStack(spacing: 0) {
                        HStack {
                            nameField.font(.title3)
                            Image(systemName: "pencil").font(.title3.weight(.semibold)).foregroundStyle(Theme.Paper.green).accessibilityHidden(true)
                        }
                        .frame(minHeight: 48)
                        Rectangle().fill(Theme.Paper.green).frame(height: 1.5).accessibilityHidden(true)
                    }
                    .accessibilityLabel("Your name")
                    PageRule()
                    heading("♥", "Your face")
                    HStack(spacing: 0) {
                        ForEach(Array(Cast.playerChoices.enumerated()), id: \.offset) { index, choice in
                            let chosen = portrait == choice
                            Button { withAnimation(Theme.Motion.press) { portrait = choice } } label: {
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
                        FaceBuilder(portrait: $portrait).padding(.top, 8)
                    }
                    .font(.title3.weight(.medium)).tint(Theme.Paper.green)
                    PageRule()
                    heading("♠", "Computer strength")
                    PaperSwitch(options: [("Easy", Difficulty.easy), ("Standard", Difficulty.standard)], selection: $difficulty, ticks: true)
                    Text("Easy players use the original strategy and lose about two matches in three to Standard. Hints always use Standard.")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                }
                .foregroundStyle(Theme.Paper.ink)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .paperCard()
                .environment(\.colorScheme, .light)
            }
            .padding(.horizontal, 12).padding(.bottom, 12)
            .frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
        .scrollDismissesKeyboard(.interactively)
        // The way in stays in sight whatever the page or the keyboard is doing (D191).
        .safeAreaInset(edge: .bottom, spacing: 0) {
            VStack(spacing: 6) {
                Button(action: sitDown) {
                    HStack(spacing: 10) {
                        Text("New match")
                        Image(systemName: "arrow.right").accessibilityHidden(true)
                    }
                }
                .buttonStyle(PaperButtonStyle())
                .disabled(trimmed.isEmpty)
                .opacity(trimmed.isEmpty ? 0.55 : 1)
                Text(trimmed.isEmpty ? "Add your name to start. It stays on this device." : "This stays on your device.")
                    .font(.footnote).foregroundStyle(.ivory.opacity(0.8))
            }
            .padding(.horizontal, 16).padding(.top, 10).padding(.bottom, 8)
            .frame(maxWidth: 480).frame(maxWidth: .infinity)
            .background(Theme.Wood.header.opacity(0.92).ignoresSafeArea(edges: .bottom))
        }
        .background(WoodGrainView().ignoresSafeArea())
        .preferredColorScheme(.dark)
        // The keyboard waits for a tap on the name: on arrival it hid the faces, the strength and the way in (D191).
        .onAppear { difficulty = model.settings.difficulty }
    }

    /// A section's name in the display serif, behind its suit, as Settings has it.
    private func heading(_ suit: String, _ title: String) -> some View {
        HStack(spacing: 10) {
            Text(suit).foregroundStyle(Color.suitRed).accessibilityHidden(true)
            Text(title).accessibilityAddTraits(.isHeader)
        }
        .font(.system(.title2, design: .serif).weight(.bold))
    }

    /// The keyboard modifiers exist only on iOS; the macOS test build needs the plain field.
    private var nameField: some View {
        let field = TextField("Your name", text: $name)
            .textContentType(.name)
            .autocorrectionDisabled()
            .focused($nameFocused)
            .submitLabel(.done)
            .onSubmit { if !trimmed.isEmpty { sitDown() } }
            .onChange(of: name) { _, new in if new.count > 24 { name = String(new.prefix(24)) } }
        #if os(iOS)
        return field.textInputAutocapitalization(.words)
        #else
        return field
        #endif
    }

    private func sitDown() {
        model.signIn(name: trimmed, portrait: portrait, difficulty: difficulty)
        onDone()
    }
}
