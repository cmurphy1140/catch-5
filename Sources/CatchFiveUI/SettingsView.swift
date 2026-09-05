import CatchFive
import SwiftUI

struct SettingsView: View {
    @Binding var settings: Settings
    @Environment(\.dismiss) private var dismiss

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
                Section("Play speed") {
                    Picker("Computer pace", selection: $settings.playSpeed) {
                        Text("Relaxed").tag(Settings.PlaySpeed.relaxed)
                        Text("Normal").tag(Settings.PlaySpeed.normal)
                        Text("Quick").tag(Settings.PlaySpeed.quick)
                    }.pickerStyle(.segmented)
                }
                Section("Names") {
                    ForEach(0..<4, id: \.self) { seat in
                        TextField(Settings.defaultSeatNames[seat], text: Binding(
                            get: { settings.seatNames[seat] },
                            set: { settings.seatNames[seat] = $0.trimmingCharacters(in: .whitespaces).isEmpty ? Settings.defaultSeatNames[seat] : $0 }))
                    }
                }
                Section {
                    Toggle("Haptics on tricks and hands", isOn: $settings.haptics)
                }
            }
            .navigationTitle("Settings")
            .toolbar { Button("Done") { dismiss() } }
        }
    }
}
