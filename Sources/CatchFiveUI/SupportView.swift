import SwiftUI

@MainActor final class SupportPresentation: Identifiable {
    let id = UUID()
    let context: SupportContext
    var session: SupportChatModel?
    /// From the opening page (D120): a general chat, whose first question may already be asked.
    var front = false
    var sendsContext = true
    var name: String?
    var opening: String?

    init(context: SupportContext) { self.context = context }
    func invalidate() { session?.invalidate() }
}

struct SupportView: View {
    let presentation: SupportPresentation
    @Environment(\.dismiss) private var dismiss
    @AppStorage("support.endpoint") private var endpoint = ""
    @AppStorage("support.code") private var code = ""
    @AppStorage("support.online") private var useOnline = false
    @State private var session: SupportChatModel?
    @State private var showSetup = false

    var body: some View {
        NavigationStack {
            Group {
                if let session {
                    SupportConversation(model: session, name: presentation.name).id(ObjectIdentifier(session))
                } else { ProgressView() }
            }
            // Ivory paper with green ink, as the other reading cards (D107).
            .foregroundStyle(Theme.Paper.ink)
            .background(Color.ivory.ignoresSafeArea())
            .tint(Theme.Paper.green)
            .navigationTitle(presentation.front ? "Chat" : "Ask anything")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() }.frame(minHeight: 44) }
                ToolbarItem(placement: .automatic) {
                    Button("Support settings", systemImage: "gearshape") { showSetup = true }
                        .labelStyle(.iconOnly).frame(minWidth: 44, minHeight: 44)
                }
            }
            #if os(iOS)
            .toolbarBackground(Color.ivory, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            #endif
        }
        .preferredColorScheme(.light)
        .sheet(isPresented: $showSetup) {
            SupportConnectionSettings(endpoint: endpoint, code: code, useOnline: useOnline) { newEndpoint, newCode, newMode in
                endpoint = newEndpoint
                code = newCode
                useOnline = newMode
                startSession()
                showSetup = false
            }
        }
        #if os(iOS)
        .presentationDetents(presentation.front ? [.large] : [.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
        .onAppear { startSession() }
        .onDisappear { session?.invalidate() }
    }

    private func startSession() {
        session?.invalidate()
        let session = SupportChatModel(context: presentation.context, client: useOnline ? SupportClient(endpoint: endpoint, code: code) : nil,
                                       front: presentation.front, sendsContext: presentation.sendsContext)
        self.session = session
        presentation.session = session
        if let opening = presentation.opening { presentation.opening = nil; session.send(opening) }
    }
}

private struct SupportConnectionSettings: View {
    @State private var endpoint: String
    @State private var code: String
    @State private var useOnline: Bool
    let onApply: (String, String, Bool) -> Void

    init(endpoint: String, code: String, useOnline: Bool, onApply: @escaping (String, String, Bool) -> Void) {
        _endpoint = State(initialValue: endpoint)
        _code = State(initialValue: code)
        _useOnline = State(initialValue: useOnline)
        self.onApply = onApply
    }
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    Toggle("Online answers", isOn: $useOnline)
                    TextField("HTTPS support endpoint", text: $endpoint).textContentType(.URL)
                    SecureField("Support access code", text: $code)
                }
                Section {
                    Text("Use your trusted support server and its access code. Never enter an OpenAI API key here. Applying starts a fresh chat.")
                        .font(.footnote)
                }
            }
            .navigationTitle("Support settings")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Close") { dismiss() }.frame(minHeight: 44) }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") { onApply(endpoint, code, useOnline) }
                        .disabled(useOnline && SupportClient(endpoint: endpoint, code: code) == nil)
                        .frame(minHeight: 44)
                }
            }
        }
    }
}

private struct SupportConversation: View {
    @ObservedObject var model: SupportChatModel
    var name: String?
    @State private var draft = ""
    @State private var expanded: Set<UUID> = []
    /// Answers that have finished typing themselves out (D120).
    @State private var typed: Set<UUID> = []
    @FocusState private var writing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(!model.online ? "Offline · Nothing leaves this device."
                         : model.front ? "OpenAI · Only what you type is sent." : "OpenAI · Your cards and public play only.")
                        .font(.caption).opacity(0.7)
                    if model.messages.isEmpty { welcome }
                    ForEach(model.messages) { message in
                        turn(message).id(message.id)
                    }
                    if model.isSending {
                        // Three dots, thinking, as a chat does (D120).
                        Image(systemName: "ellipsis").font(.title).symbolEffect(.variableColor.iterative, isActive: !reduceMotion)
                            .foregroundStyle(Theme.Paper.green).accessibilityLabel("Getting an answer")
                    }
                    if let question = model.failedQuestion {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(model.error ?? "Question cancelled.").font(.callout)
                            HStack(spacing: 20) {
                                Button("Try again") { model.send(question) }.frame(minHeight: 44)
                                Button("Offline help") { model.useLocalFallback() }.frame(minHeight: 44)
                            }
                            .font(.callout.weight(.semibold))
                        }
                    } else if let error = model.error { Text(error).font(.callout) }
                }
                .frame(maxWidth: 600, alignment: .leading).frame(maxWidth: .infinity)
                .padding(20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .onChange(of: model.messages.last(where: { $0.role == "user" })?.id) { _, id in
                // Reveal only an explicitly submitted question. New answers and More never force a scroll.
                if let id { proxy.scrollTo(id, anchor: .top) }
            }
        }
    }

    private var welcome: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let guest {
                guest.resizable().scaledToFit().frame(height: 210).frame(maxWidth: .infinity).accessibilityHidden(true)
            }
            Text(model.front ? "Hi Emma, or friends!" : "Ask about this hand, or just chat")
                .font(.system(.title2, design: .serif).weight(.semibold))
            ForEach(starters, id: \.question) { starter in
                Button(action: starter.ask) {
                    HStack {
                        Text(starter.question)
                        Spacer(minLength: 8)
                        Image(systemName: "arrow.up.left").font(.caption)
                    }
                    .font(.body.weight(.medium)).foregroundStyle(Theme.Paper.green)
                    .padding(.horizontal, 14).frame(minHeight: 48)
                    .background(Theme.Paper.wash, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.Paper.rule))
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The guest of honour's picture for the opening page's chat, when the build carries one (D122, D124). It is kept
    /// out of the repository, so most builds have none.
    private var guest: Image? {
        #if canImport(UIKit)
        guard model.front, UIImage(named: "Guest") != nil else { return nil }
        return Image("Guest")
        #else
        return nil
        #endif
    }

    private var starters: [(question: String, ask: () -> Void)] {
        model.front ? FrontDesk.starters.map { question in (question, { model.send(question) }) }
            : SupportPrompt.starters(in: model.context).map { prompt in (prompt.question(in: model.context), { model.quickHelp(prompt) }) }
                + [(FrontDesk.starters[0], { model.send(FrontDesk.starters[0]) })]
    }

    private func turn(_ message: SupportTurn) -> some View {
        let user = message.role == "user"
        let visible = user || expanded.contains(message.id) ? message.text : message.preview
        return HStack(alignment: .top, spacing: 0) {
            if user { Spacer(minLength: 30) }
            VStack(alignment: .leading, spacing: 6) {
                if message.isLocal { Text("Offline help").font(.caption).opacity(0.65) }
                // The newest answer types itself out once (D120); Reduce Motion shows it whole.
                TypedText(text: visible, animate: !user && !reduceMotion && message.id == model.messages.last?.id && !typed.contains(message.id)) { typed.insert(message.id) }
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel(user ? "You: \(visible)" : message.isLocal ? "Offline help: \(visible)" : visible)
                if !user, message.preview != message.text {
                    Button(expanded.contains(message.id) ? "Less" : "More") {
                        if !expanded.insert(message.id).inserted { expanded.remove(message.id) }
                    }
                    .font(.callout.weight(.semibold))
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .accessibilityHint("Expands or collapses this answer without asking again")
                }
            }
            .padding(user ? 12 : 0)
            .foregroundStyle(user ? .ivory : Theme.Paper.ink)
            .background(user ? Theme.Paper.green : .clear, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            if !user { Spacer(minLength: 12) }
        }
    }

    private var composer: some View {
        HStack(alignment: .bottom, spacing: 10) {
            TextField(model.front ? "Ask anything" : "Ask about this game", text: $draft, axis: .vertical)
                .lineLimit(1...4).submitLabel(.send).onSubmit(send)
                .focused($writing)
                .padding(.horizontal, 16).padding(.vertical, 11)
                .background(.ivory, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).stroke(Theme.Paper.rule, lineWidth: 1.5))
                .disabled(model.isSending)
                // With a guest's picture on the page the keyboard waits, so the picture is seen first (D122).
                .onAppear { if model.front, model.messages.isEmpty, guest == nil { writing = true } }
            if model.isSending {
                Button("Cancel") { model.cancel() }.frame(minWidth: 44, minHeight: 44)
            } else {
                Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                    .labelStyle(.iconOnly).font(.title).foregroundStyle(Theme.Paper.green).frame(minWidth: 44, minHeight: 44)
                    .disabled(draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !SupportMessage.fits(draft))
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 12)
        .background(Theme.Paper.tan)
        .overlay(alignment: .top) { Rectangle().fill(Theme.Paper.rule).frame(height: 1) }
    }

    private func send() {
        guard !model.isSending, !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, SupportMessage.fits(draft) else { return }
        model.send(draft)
        draft = ""
    }
}

/// Text that types itself out, as a chat's answer does (D120). `done` fires once the whole text is showing.
private struct TypedText: View {
    let text: String
    let animate: Bool
    let done: () -> Void
    @State private var shown = 0

    var body: some View {
        Text(animate ? String(text.prefix(shown)) : text)
            .frame(maxWidth: .infinity, alignment: .leading)
            .task(id: text) {
                guard animate else { return }
                while shown < text.count {
                    shown = min(text.count, shown + 3)
                    try? await Task.sleep(for: .milliseconds(18))
                    if Task.isCancelled { break }
                }
                done()
            }
    }
}
