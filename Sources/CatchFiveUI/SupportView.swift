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
    /// Local completed-hand navigation. No replay or other seats' cards enter the support transport.
    var completedTrickNumbers: [Int] = []
    var onReplayTrick: ((Int) -> Void)?

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
    @State private var showNotebook = false

    var body: some View {
        VStack(spacing: 0) {
            // The cloth band of the other pages (D184), carrying the notebook of kept answers (D131) and the settings.
            ClothHeader(title: presentation.front ? "Chat" : "Ask anything", tools: [
                ClothTool(label: "Notebook", symbol: "book.closed") { showNotebook = true },
                ClothTool(label: "Support settings", symbol: "gearshape") { showSetup = true },
            ]) { dismiss() }
            .zIndex(1)
            Group {
                if let session {
                    SupportConversation(model: session, name: presentation.name,
                                        completedTrickNumbers: presentation.completedTrickNumbers,
                                        onReplayTrick: presentation.onReplayTrick)
                        .id(ObjectIdentifier(session))
                } else { ProgressView().frame(maxHeight: .infinity) }
            }
            // Ivory paper with green ink, as the other reading cards (D107).
            .foregroundStyle(Theme.Paper.ink)
            .background(Color.ivory.ignoresSafeArea())
            .tint(Theme.Paper.green)
        }
        .background(WoodGrainView().ignoresSafeArea())
        .preferredColorScheme(.light)
        .sheet(isPresented: $showNotebook) { NotebookView() }
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
        // Paper, not a system form (D154): the title in the serif, two soft cards, the caution at the foot.
        VStack(spacing: 0) {
            HStack {
                Button("Close") { dismiss() }
                Spacer()
                Button("Apply") { onApply(endpoint, code, useOnline) }
                    .disabled(useOnline && SupportClient(endpoint: endpoint, code: code) == nil)
            }
            .font(.title3).modifier(BareButton()).frame(minHeight: 44)
            Text("Support settings").font(.system(.largeTitle, design: .serif).weight(.bold)).foregroundStyle(Theme.Paper.green)
                .padding(.top, 14).padding(.bottom, 26).accessibilityAddTraits(.isHeader)
            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 0) {
                    Toggle("On-call helper", isOn: $useOnline).tint(Theme.Paper.green).frame(minHeight: 44)
                    Rectangle().fill(Theme.Paper.rule.opacity(0.5)).frame(height: 1).padding(.vertical, 10)
                    Text("Support station address")
                    TextField("An https address", text: $endpoint).textContentType(.URL).autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never).keyboardType(.URL)
                        #endif
                        .font(.body).foregroundStyle(Theme.Paper.green).frame(minHeight: 36)
                }
                .modifier(SettingsCard())
                VStack(alignment: .leading, spacing: 0) {
                    Text("Access code")
                    HStack {
                        SecureField("From whoever runs the helper", text: $code).font(.body).foregroundStyle(Theme.Paper.green)
                        Image(systemName: "lock").foregroundStyle(Theme.Paper.green).accessibilityHidden(true)
                    }
                    .frame(minHeight: 36)
                }
                .modifier(SettingsCard())
            }
            .font(.title3).foregroundStyle(Theme.Paper.ink)
            Spacer(minLength: 20)
            Text("Use your own trusted helper's address and its access code. Never enter an OpenAI key here. Applying starts a fresh chat.")
                .font(.footnote).multilineTextAlignment(.center).foregroundStyle(Theme.Paper.ink).padding(.horizontal, 12)
        }
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 16)
        .frame(maxWidth: 520).frame(maxWidth: .infinity)
        .background(Color.ivory.ignoresSafeArea())
        .environment(\.colorScheme, .light)
    }
}

/// A soft card on the paper for a group of settings (D154): a shade lighter than the page, no outline.
private struct SettingsCard: ViewModifier {
    func body(content: Content) -> some View {
        content.padding(.horizontal, 18).padding(.vertical, 14).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white.opacity(0.55), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

/// Disclosure state belongs to the draft, not to keyboard focus. A manual reopening survives later typing.
struct SupportStarterDisclosure {
    var isExpanded = true
    private(set) var hasBegunDraft = false

    mutating func draftChanged(to text: String) {
        guard !hasBegunDraft, !text.isEmpty else { return }
        hasBegunDraft = true
        isExpanded = false
    }
}

struct SupportConversation: View {
    @ObservedObject private var notebook = Notebook.shared
    @ObservedObject var model: SupportChatModel
    var name: String?
    let completedTrickNumbers: [Int]
    let onReplayTrick: ((Int) -> Void)?
    @State private var draft = ""
    @State private var expanded: Set<UUID> = []
    /// Answers that have finished typing themselves out (D120).
    @State private var typed: Set<UUID> = []
    @State private var starterDisclosure = SupportStarterDisclosure()
    @FocusState private var writing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    init(model: SupportChatModel, name: String? = nil, initialDraft: String = "",
         completedTrickNumbers: [Int] = [], onReplayTrick: ((Int) -> Void)? = nil) {
        self.model = model
        self.name = name
        self.completedTrickNumbers = Array(Set(completedTrickNumbers.filter { (1...6).contains($0) })).sorted()
        self.onReplayTrick = onReplayTrick
        _draft = State(initialValue: initialDraft)
        var disclosure = SupportStarterDisclosure()
        disclosure.draftChanged(to: initialDraft)
        _starterDisclosure = State(initialValue: disclosure)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text(model.transmissionDescription)
                        .font(.caption).opacity(0.7)
                    completedTrickReview
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
                            .font(.callout.weight(.semibold)).modifier(BareButton())
                        }
                    } else if let error = model.error { Text(error).font(.callout) }
                }
                .frame(maxWidth: 600, alignment: .leading).frame(maxWidth: .infinity)
                .padding(20)
            }
            .safeAreaInset(edge: .bottom, spacing: 0) { composer }
            .onChange(of: draft) { _, text in
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
                    starterDisclosure.draftChanged(to: text)
                }
            }
            .onChange(of: model.messages.last(where: { $0.role == "user" })?.id) { _, id in
                // Reveal only an explicitly submitted question. New answers and More never force a scroll.
                if let id { proxy.scrollTo(id, anchor: .top) }
            }
        }
    }

    /// This route stays available after a question, and invokes only the local presentation callback.
    @ViewBuilder private var completedTrickReview: some View {
        if let onReplayTrick, !completedTrickNumbers.isEmpty {
            DisclosureGroup("Review a trick") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Play the four cards again and see why one won.")
                        .font(.subheadline).fixedSize(horizontal: false, vertical: true)
                    ForEach(completedTrickNumbers, id: \.self) { number in
                        Button { onReplayTrick(number) } label: {
                            HStack(spacing: 12) {
                                Text("Trick \(number)").multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                Image(systemName: "play.rectangle").accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
                        .accessibilityLabel("Replay trick \(number)")
                        .accessibilityHint("Opens the recorded cards and the winning-card explanation")
                    }
                }
                .padding(.top, 10)
            }
            .font(.headline).tint(Theme.Paper.green)
            .frame(minHeight: 44)
        }
    }

    /// The greeting beside the two hands passing the five, when the build carries the picture, and under it the
    /// suggestions as plain rows between hairlines (D184), where there were glass chips (D146).
    private var welcome: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 8) {
                Text(greeting)
                    .font(.system(model.front ? .largeTitle : .title2, design: .serif).weight(.bold))
                    .foregroundStyle(Theme.Paper.greenDeep)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                if model.front, !dynamicTypeSize.isAccessibilitySize, let hands = SeatArt.named("GuestMenuHero") {
                    hands.resizable().scaledToFit().frame(width: dynamicTypeSize > .large ? 96 : 128)
                        .accessibilityHidden(true)
                }
            }
            VStack(alignment: .leading, spacing: 0) {
                Button {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { starterDisclosure.isExpanded.toggle() }
                } label: {
                    HStack(spacing: 8) {
                        Text("Suggested prompts").font(.system(.title3, design: .serif).weight(.semibold))
                        Image(systemName: "chevron.up").font(.footnote.weight(.bold)).rotationEffect(.degrees(starterDisclosure.isExpanded ? 0 : 180))
                    }
                    .foregroundStyle(Theme.Team.theirRim).frame(minHeight: 44).contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityValue(starterDisclosure.isExpanded ? "Shown" : "Hidden")
                if starterDisclosure.isExpanded {
                    ForEach(starters, id: \.question) { starter in
                        Rectangle().fill(Theme.Paper.rule.opacity(0.6)).frame(height: 1).accessibilityHidden(true)
                        Button(action: starter.ask) {
                            HStack(spacing: 10) {
                                Text(starter.question).font(.system(.title3, design: .serif).weight(.medium))
                                    .foregroundStyle(Theme.Paper.greenDeep).multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                                Image(systemName: "chevron.right").font(.footnote.weight(.bold)).foregroundStyle(Theme.Paper.rule)
                                    .accessibilityHidden(true)
                            }
                            .padding(.horizontal, 6).frame(minHeight: 48).contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    Rectangle().fill(Theme.Paper.rule.opacity(0.6)).frame(height: 1).accessibilityHidden(true)
                }
            }
        }
    }

    private var greeting: String {
        guard model.front else { return "Ask about this hand, or just chat" }
        guard let name = name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return "Pull up a chair."
        }
        return "Hi, \(name)!"
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
                    .font(.callout.weight(.semibold)).modifier(BareButton())
                    .frame(minWidth: 44, minHeight: 44, alignment: .leading)
                    .accessibilityHint("Expands or collapses this answer without asking again")
                }
                if !user {
                    // Keep this answer in the notebook, or let it go (D131).
                    let kept = notebook.holds(message.text)
                    Button(kept ? "Kept in notebook" : "Keep in notebook", systemImage: kept ? "bookmark.fill" : "bookmark") {
                        notebook.toggle(message.text)
                    }
                    .labelStyle(.iconOnly).modifier(BareButton())
                    .frame(minWidth: 44, minHeight: 36, alignment: .leading)
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
                .onAppear { if model.front, model.messages.isEmpty { writing = true } }
            if model.isSending {
                Button("Cancel") { model.cancel() }.modifier(BareButton()).frame(minWidth: 44, minHeight: 44)
            } else {
                Button("Send", systemImage: "arrow.up.circle.fill", action: send)
                    .labelStyle(.iconOnly).font(.title).modifier(BareButton()).frame(minWidth: 44, minHeight: 44)
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

/// A chip of frosted glass (D146): the system's own glass where the phone has it, and before that a thin material
/// with a light rim, so the chip reads as glass on paper either way.
struct FrostedChip: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26, macOS 26, *) {
            content.glassEffect(.regular.interactive(), in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.white.opacity(0.7), lineWidth: 1))
                .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
        }
    }
}

/// A button with nothing drawn round it (D152): no system pill, no grey plate under the finger or the pointer. The
/// words or the symbol are the whole control, in the paper's green.
struct BareButton: ViewModifier {
    func body(content: Content) -> some View {
        #if os(iOS)
        content.buttonStyle(.plain).foregroundStyle(Theme.Paper.green).hoverEffectDisabled()
        #else
        content.buttonStyle(.plain).foregroundStyle(Theme.Paper.green)
        #endif
    }
}
