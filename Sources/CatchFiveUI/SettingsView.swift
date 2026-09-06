import CatchFive
import SwiftUI

struct SettingsView: View {
    @Binding var settings: Settings
    @Environment(\.dismiss) private var dismiss
    @State private var showExplainer = false
    @State private var nameDraft = ""

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Computer strength", selection: $settings.difficulty) {
                        Text("Easy").tag(Difficulty.easy)
                        Text("Standard").tag(Difficulty.standard)
                    }.pickerStyle(.segmented)
                } header: { Text("Difficulty") } footer: {
                    Text("Easy players use the original strategy and lose about two matches in three to Standard. Hints always use Standard.")
                }
                Section {
                    Toggle("Beginner mode", isOn: $settings.beginnerMode)
                } header: { Text("Assistance") } footer: {
                    Text("Hints, tap-to-explain on the table and what each trump would keep. Off is normal mode: the same rules and a clean table.")
                }
                Section("Play speed") {
                    Picker("Computer pace", selection: $settings.playSpeed) {
                        Text("Relaxed").tag(Settings.PlaySpeed.relaxed)
                        Text("Normal").tag(Settings.PlaySpeed.normal)
                        Text("Quick").tag(Settings.PlaySpeed.quick)
                    }.pickerStyle(.segmented)
                }
                Section("You") {
                    // A draft, so spaces and clearing work while typing; each non-blank edit is committed.
                    TextField("Your name", text: $nameDraft)
                        .onAppear { nameDraft = settings.playerName ?? settings.seatNames[0] }
                        .onChange(of: nameDraft) { _, new in settings.setPlayerName(new) }
                    HStack(spacing: 16) {
                        ForEach(Array(Cast.playerChoices.enumerated()), id: \.offset) { index, choice in
                            Button { settings.playerPortrait = choice } label: {
                                PortraitView(portrait: choice, size: 44)
                                    .opacity(settings.playerPortrait == choice ? 1 : Theme.Card.dimmedOpacity)
                                    .overlay(Circle().stroke(.gold, lineWidth: settings.playerPortrait == choice ? 3 : 0))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Face \(index + 1)")
                            .accessibilityAddTraits(settings.playerPortrait == choice ? .isSelected : [])
                        }
                    }.frame(maxWidth: .infinity)
                }
                Section("Opponents") {
                    ForEach(1..<4, id: \.self) { seat in
                        HStack(spacing: 12) {
                            if let character = Cast.opponent(at: seat) { PortraitView(portrait: character.portrait, size: 28) }
                            TextField(Settings.defaultSeatNames[seat], text: Binding(
                                get: { settings.seatNames[seat] },
                                set: { settings.seatNames[seat] = $0.trimmingCharacters(in: .whitespaces).isEmpty ? Settings.defaultSeatNames[seat] : $0 }))
                        }
                    }
                }
                Section {
                    Toggle("Haptics on tricks and hands", isOn: $settings.haptics)
                }
                Section {
                    Button { showExplainer = true } label: { Label("How Catch 5 is built", systemImage: "doc.text.magnifyingglass") }
                } header: { Text("About") } footer: {
                    Text("The engineering explainer: architecture, game flow, every type, the tests and the decision log, readable offline.")
                }
            }
            #if canImport(UIKit)
            .sheet(isPresented: $showExplainer) { ExplainerView { showExplainer = false } }
            #endif
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
