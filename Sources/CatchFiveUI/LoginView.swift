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
            VStack(spacing: 28) {
                VStack(spacing: 4) {
                    Text("CATCH 5").font(.system(.largeTitle, design: .serif).weight(.bold))
                    Text("SET UP YOUR PLAYER").font(.system(.caption2, design: .monospaced).weight(.medium)).tracking(1).opacity(0.7)
                }
                .padding(.top, 40)

                VStack(alignment: .leading, spacing: 8) {
                    Text("What should we call you?").font(.headline)
                    nameField
                        .padding(12)
                        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .accessibilityLabel("Your name")
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Pick a face").font(.headline)
                    HStack(spacing: 16) {
                        ForEach(Array(Cast.playerChoices.enumerated()), id: \.offset) { index, choice in
                            Button { withAnimation(Theme.Motion.press) { portrait = choice } } label: {
                                PortraitView(portrait: choice, size: 72)
                                    .opacity(portrait == choice ? 1 : Theme.Card.dimmedOpacity)
                                    .overlay(Circle().stroke(.gold, lineWidth: portrait == choice ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Face \(index + 1)")
                            .accessibilityAddTraits(portrait == choice ? .isSelected : [])
                        }
                    }.frame(maxWidth: .infinity)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Computer strength").font(.headline)
                    Picker("Computer strength", selection: $difficulty) {
                        Text("Easy").tag(Difficulty.easy)
                        Text("Standard").tag(Difficulty.standard)
                    }.pickerStyle(.segmented)
                    Text("Easy players use the original strategy and lose about two matches in three to Standard. Hints always use Standard.")
                        .font(.footnote).opacity(0.7)
                }

                Button(action: sitDown) {
                    Text("New match").font(.headline).frame(maxWidth: .infinity).frame(minHeight: 50)
                }
                .buttonStyle(.borderedProminent).tint(.gold).foregroundStyle(.black)
                .disabled(trimmed.isEmpty)
                .padding(.top, 8)
            }
            .padding(24).frame(maxWidth: 480).frame(maxWidth: .infinity)
        }
        .foregroundStyle(.ivory)
        .background(LinearGradient(colors: [.felt, .black], startPoint: .topLeading, endPoint: .bottomTrailing).ignoresSafeArea())
        .preferredColorScheme(.dark)
        .onAppear { difficulty = model.settings.difficulty; nameFocused = true }
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
