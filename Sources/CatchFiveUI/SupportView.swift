import SwiftUI

@MainActor final class SupportPresentation: Identifiable {
    let id = UUID()
    let context: SupportContext
    var session: SupportChatModel?

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
                    SupportConversation(model: session).id(ObjectIdentifier(session))
                } else { ProgressView() }
            }
            // Ivory paper with green ink, as the other reading cards (D107).
            .foregroundStyle(Theme.Paper.ink)
            .background(Color.ivory.ignoresSafeArea())
            .tint(Theme.Paper.green)
            .navigationTitle("Support")
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
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        #endif
        .onAppear { startSession() }
        .onDisappear { session?.invalidate() }
    }

    private func startSession() {
        session?.invalidate()
        session = SupportChatModel(context: presentation.context, client: useOnline ? SupportClient(endpoint: endpoint, code: code) : nil)
        presentation.session = session
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
    @State private var draft = ""
    @State private var expanded: Set<UUID> = []

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(model.online ? "OpenAI · Your cards and public play only."
                         : "Offline · Nothing leaves this device.")
                        .font(.caption).opacity(0.7)
                    if model.messages.isEmpty { welcome }
                    ForEach(model.messages) { message in
                        turn(message).id(message.id)
                    }
                    if model.isSending {
                        ProgressView("Getting an answer…").font(.callout)
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
            Text("Ask about this hand").font(.system(.title2, design: .serif).weight(.semibold))
            ForEach(SupportPrompt.starters(in: model.context)) { prompt in
                Button { model.quickHelp(prompt) } label: {
                    HStack {
                        Text(prompt.question(in: model.context))
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

    private func turn(_ message: SupportTurn) -> some View {
        let user = message.role == "user"
        let visible = user || expanded.contains(message.id) ? message.text : message.preview
        return HStack(alignment: .top, spacing: 0) {
            if user { Spacer(minLength: 30) }
            VStack(alignment: .leading, spacing: 6) {
                if message.isLocal { Text("Offline help").font(.caption).opacity(0.65) }
                Text(visible)
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
            TextField("Ask about this game", text: $draft, axis: .vertical)
                .lineLimit(1...4).submitLabel(.send).onSubmit(send)
                .padding(10)
                .background(.ivory, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Theme.Paper.green, lineWidth: 1.5))
                .disabled(model.isSending)
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
