import SwiftUI

/// The player's notebook (D131): helper answers they chose to keep and lines of their own, a cheat sheet they can edit.
/// It lives on this device only and is never sent anywhere.
@MainActor
final class Notebook: ObservableObject {
    struct Note: Identifiable, Codable, Equatable {
        var id = UUID()
        var text: String
    }

    static let shared = Notebook()
    static let key = "notebook.notes"

    @Published var notes: [Note] { didSet { save() } }
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        notes = defaults.data(forKey: Self.key).flatMap { try? JSONDecoder().decode([Note].self, from: $0) } ?? []
    }

    func holds(_ text: String) -> Bool { notes.contains { $0.text == text } }

    /// Keeps an answer, or lets it go if it is already kept unedited.
    func toggle(_ text: String) {
        if holds(text) { notes.removeAll { $0.text == text } } else { notes.append(Note(text: text)) }
    }

    /// Blank lines are dropped on the way to disk, so an abandoned new line does not come back.
    private func save() {
        let kept = notes.filter { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if let data = try? JSONEncoder().encode(kept) { defaults.set(data, forKey: Self.key) }
    }
}

/// The notebook's page: ruled ivory paper in the handwriting of the scores, every line editable, with delete and
/// reorder under Edit and a new line at the foot.
struct NotebookView: View {
    @ObservedObject var notebook: Notebook
    let guestNote: GuestNote?
    @Environment(\.dismiss) private var dismiss
    @FocusState private var writing: UUID?
    @State private var showNote = false

    @MainActor init(notebook: Notebook? = nil, guestNote: GuestNote? = GuestNote.current, showLetter: Bool = false) {
        self.notebook = notebook ?? .shared
        self.guestNote = guestNote
        _showNote = State(initialValue: showLetter)
    }

    var body: some View {
        NavigationStack {
            List {
                if let note = guestNote {
                    VStack(spacing: 18) {
                        GuestMailboxButton(name: note.name) { writing = nil; showNote = true }
                        Rectangle().fill(Theme.Paper.rule).frame(height: 1)
                    }
                    .padding(.top, 10).padding(.bottom, 6)
                    .listRowBackground(Color.clear).listRowSeparator(.hidden)
                }
                if notebook.notes.isEmpty {
                    Text("Nothing here yet. Tap the bookmark under any answer in the chat to keep it, or write a line of your own.")
                        .font(.callout).opacity(0.7).listRowBackground(Color.clear)
                }
                ForEach($notebook.notes) { $note in
                    TextField("A note", text: $note.text, axis: .vertical)
                        .font(.custom("Noteworthy-Bold", size: 18, relativeTo: .body))
                        .focused($writing, equals: note.id)
                        .listRowBackground(Color.clear)
                }
                .onDelete { notebook.notes.remove(atOffsets: $0) }
                .onMove { notebook.notes.move(fromOffsets: $0, toOffset: $1) }
                Button("Write a line", systemImage: "pencil") {
                    let note = Notebook.Note(text: "")
                    notebook.notes.append(note)
                    writing = note.id
                }
                .frame(minHeight: 44).listRowBackground(Color.clear)
            }
            .listStyle(.plain)
            .listRowSeparatorTint(Theme.Paper.rule)
            .scrollContentBackground(.hidden)
            .foregroundStyle(Theme.Paper.ink)
            .background(Color.ivory.ignoresSafeArea())
            .tint(Theme.Paper.green)
            .navigationTitle("Notebook")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.ivory, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.frame(minHeight: 44) }
                #if os(iOS)
                ToolbarItem(placement: .cancellationAction) { EditButton().frame(minHeight: 44) }
                #endif
            }
        }
        .allowsHitTesting(!showNote)
        .accessibilityHidden(showNote)
        .overlay { if showNote, let note = guestNote { GuestNoteCard(note: note) { showNote = false } } }
        // Paper is light whatever the device is set to.
        .environment(\.colorScheme, .light)
    }
}
