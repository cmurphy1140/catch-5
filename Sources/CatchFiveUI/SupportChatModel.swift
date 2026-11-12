import Combine
import Foundation

struct SupportTurn: Identifiable {
    let id = UUID()
    let role: String
    let text: String
    var isLocal = false
    var preview: String { SupportMessage(role: role, text: text).preview }
}

/// Owned only by the presented sheet. Dismissal and any table revision invalidate the session.
@MainActor final class SupportChatModel: ObservableObject {
    @Published private(set) var messages: [SupportTurn] = []
    @Published private(set) var isSending = false
    @Published private(set) var error: String?
    @Published private(set) var failedQuestion: String?
    let context: SupportContext
    let online: Bool
    /// Opened from the opening page (D120): general questions, and the game's context goes along only if one is saved.
    let front: Bool
    private let sendsContext: Bool

    /// Describes the actual payload policy; the entry screen alone does not determine what is shared.
    var transmissionDescription: String {
        guard online else { return "Offline · Nothing leaves this device." }
        return sendsContext ? "OpenAI · Your messages, cards and public play are sent."
            : "OpenAI · Only this conversation is sent."
    }
    private let client: SupportClient?
    private var task: Task<Void, Never>?
    private var generation = 0
    private var valid = true
    private var remoteMessages: [SupportMessage] = []
    private var pendingQuestion: String?
    private var pendingPrompt: SupportPrompt?
    private var failedPrompt: SupportPrompt?

    init(context: SupportContext, client: SupportClient?, front: Bool = false, sendsContext: Bool = true) {
        self.context = context
        self.front = front
        self.sendsContext = sendsContext
        self.client = client
        online = client != nil
    }

    func quickHelp(_ prompt: SupportPrompt) {
        send(prompt.question(in: context), prompt: prompt)
    }

    func localHelp(_ prompt: SupportPrompt) {
        guard valid, !isSending else { return }
        messages += [.init(role: "user", text: prompt.question(in: context)), .init(role: "assistant", text: context.localAnswer(prompt), isLocal: true)]
        error = nil
        failedQuestion = nil
        failedPrompt = nil
    }

    func useLocalFallback() {
        guard valid, !isSending, let question = failedQuestion else { return }
        messages.append(.init(role: "assistant", text: localAnswer(question, failedPrompt), isLocal: true))
        error = nil
        failedQuestion = nil
        failedPrompt = nil
    }

    func send(_ text: String, prompt: SupportPrompt? = nil) {
        guard valid, !isSending else { return }
        let question = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, SupportMessage.fits(question) else {
            error = "Keep your question within 2,000 text characters."
            return
        }
        let retrying = failedQuestion == question && messages.last?.role == "user" && messages.last?.text == question
        let intent = prompt ?? (retrying ? failedPrompt : nil)
        if !retrying { messages.append(.init(role: "user", text: question)) }
        failedQuestion = nil
        failedPrompt = nil
        error = nil
        guard let client else {
            messages.append(.init(role: "assistant", text: localAnswer(question, intent), isLocal: true))
            return
        }
        let remoteHistory = Array(remoteMessages.suffix(8))
        isSending = true
        pendingQuestion = question
        pendingPrompt = intent
        generation += 1
        let current = generation
        task = Task { [weak self, context, front, sendsContext] in
            do {
                let reply = try await client.reply(messages: remoteHistory + [.init(role: "user", text: question)], context: sendsContext ? context : nil, place: front ? "menu" : nil)
                guard let self, self.valid, self.generation == current, !Task.isCancelled else { return }
                self.messages.append(.init(role: "assistant", text: reply))
                self.remoteMessages = remoteHistory + [.init(role: "user", text: question), .init(role: "assistant", text: SupportMessage.historyText(reply))]
                self.isSending = false
                self.pendingQuestion = nil
                self.pendingPrompt = nil
                self.task = nil
            } catch {
                guard let self, self.valid, self.generation == current, !Task.isCancelled else { return }
                self.failedQuestion = question
                self.failedPrompt = intent
                self.error = "Couldn't get an answer. Try again or use offline help."
                self.isSending = false
                self.pendingQuestion = nil
                self.pendingPrompt = nil
                self.task = nil
            }
        }
    }

    func cancel() {
        generation += 1
        task?.cancel()
        task = nil
        if isSending { failedQuestion = pendingQuestion; failedPrompt = pendingPrompt }
        pendingQuestion = nil
        pendingPrompt = nil
        isSending = false
        error = nil
    }

    func invalidate() {
        cancel()
        valid = false
        messages = []
        remoteMessages = []
        failedQuestion = nil
        failedPrompt = nil
    }

    private func localAnswer(_ question: String, _ intent: SupportPrompt?) -> String {
        if front { return FrontDesk.localAnswer(question) }
        // At the table a starter's intent wins; free text may be plain chat (D120).
        return intent.map(context.localAnswer) ?? FrontDesk.chat(question) ?? context.localAnswer(Self.prompt(for: question))
    }

    private static func prompt(for question: String) -> SupportPrompt {
        let lower = question.lowercased()
        if lower.contains("should") || lower.contains("recommend") { return .advice }
        if lower.contains("scor") || lower.contains("happening") || lower.contains("hand going") || lower.contains("next") { return .state }
        return .rules
    }
}

extension SupportMessage {
    /// Presentation only: expansion reveals the same complete reply without a second request.
    var preview: String {
        let words = text.split(whereSeparator: \.isWhitespace)
        guard words.count > 80 || text.utf16.count > 700 else { return text }
        var result = ""
        for word in words.prefix(60) {
            let next = result.isEmpty ? String(word) : result + " " + word
            guard next.utf16.count <= 600 else { break }
            result = next
        }
        guard !result.isEmpty else { return "More detail is available." }
        if let end = result.indices.last(where: { index in
            let next = result.index(after: index)
            return ".!?".contains(result[index]) && (next == result.endIndex || result[next].isWhitespace)
        }) {
            return String(result[...end])
        }
        return result + "…"
    }
}
