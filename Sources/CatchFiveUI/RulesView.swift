import SwiftUI

struct RulesView: View {
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    ForEach(RulesText.sections, id: \.title) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title).font(.headline)
                            ForEach(section.paragraphs, id: \.self) { Text($0).font(.body) }
                        }
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Reading the table").font(.headline)
                        ForEach(RulesText.readingTheTable, id: \.self) { Text($0).font(.body) }
                    }
                }
                .padding(20)
            }
            .navigationTitle("How to play Catch 5")
            .toolbar { Button("Done", action: onDismiss) }
        }
    }
}
