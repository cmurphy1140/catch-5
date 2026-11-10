import CatchFive
import Foundation
import Testing
@testable import CatchFiveUI

private let supportDeck = Suit.allCases.flatMap { suit in Rank.allCases.map { Card(suit, $0) } }

@Test func supportPayloadIgnoresOpponentCardMutation() throws {
    let first = try Match(deck: supportDeck, dealer: 3)
    var changed = supportDeck
    changed.swapAt(3, 6) // Seats 1 and 2 change; seat 0 and every public fact stay identical.
    let second = try Match(deck: changed, dealer: 3)
    let a = try SupportContext(match: first, seat: 0)
    let b = try SupportContext(match: second, seat: 0)
    #expect(a == b)
    #expect(a.cards.count == 6)
    #expect(a.legalOptions.contains("Bid 2"))
    #expect(a.recommendation != nil)
    let encoder = JSONEncoder(); encoder.outputFormatting = .sortedKeys
    #expect(try encoder.encode(a) == encoder.encode(b))
    let json = String(decoding: try encoder.encode(a), as: UTF8.self)
    #expect(!json.contains("hands"))
    #expect(!json.contains("stock"))
}

@Test func supportReportsCanonicalLegalCardsAndFinishedScore() throws {
    var match = try Match(deck: supportDeck, dealer: 3)
    try match.bid(seat: 0, amount: 9)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    let context = try SupportContext(match: match, seat: 0)
    #expect(context.legalOptions == match.hand.legalMoves(seat: 0).map { "Play \($0.name)" })
    while let seat = match.hand.nextSeat {
        try match.play(seat: seat, card: #require(match.hand.legalMoves(seat: seat).first))
    }
    let finished = try SupportContext(match: match, seat: 0)
    #expect(finished.legalOptions.isEmpty)
    #expect(finished.outcome?.points == match.hand.result?.points)
    #expect(finished.outcome?.scores == match.scores)
    #expect(finished.localAnswer(.state).contains("Game values"))
}

@MainActor @Test func supportCurtainHidesContextAndNextSeatGetsFreshContext() throws {
    let game = GameModel(match: try Match(deck: supportDeck, dealer: 3), mode: .passAndPlay)
    #expect(SupportContext.visible(in: game) == nil)
    game.ready()
    #expect(SupportContext.visible(in: game)?.seat == 0)
    game.send(.bid(2))
    #expect(SupportContext.visible(in: game) == nil)
    game.ready()
    #expect(SupportContext.visible(in: game)?.seat == 1)
}

@MainActor @Test func supportLocalHelpWorksWithoutConfiguration() async throws {
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    let model = SupportChatModel(context: context, client: nil)
    for prompt in SupportPrompt.allCases { model.quickHelp(prompt) }
    #expect(model.messages.filter { $0.role == "assistant" }.count == 3)
    #expect(model.messages.last?.isLocal == true)
    model.send("How do I play?")
    #expect(model.messages.last?.isLocal == true)
    #expect(!model.isSending)
}

@Test func supportRejectsUnsafeEndpoints() {
    for endpoint in ["http://example.com", "https://user:pass@example.com", "https://example.com?q=x", "https://example.com/#x"] {
        #expect(SupportClient(endpoint: endpoint, code: "test") == nil)
    }
    #expect(SupportClient(endpoint: "https://example.com/api/support", code: "test") != nil)
}

@Test func supportClientSendsBoundedContractAndParsesReply() async throws {
    let candidate = SupportClient(endpoint: "https://example.com/api/support", code: "access", transport: { @Sendable request in
        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "x-support-code") == "access")
        let data = try #require(request.httpBody)
        let object = try JSONSerialization.jsonObject(with: data)
        let body = try #require(object as? [String: Any])
        #expect(Set(body.keys) == Set(["messages", "context"]))
        return (Data(#"{"reply":"Try bidding 2."}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    })
    let client = try #require(candidate)
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    #expect(try await client.reply(messages: [.init(role: "user", text: "Help")], context: context) == "Try bidding 2.")
}

@Test func supportClientRejectsErrorsAndEmptyReplies() async throws {
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    for (status, data) in [(401, #"{"error":"private"}"#), (200, #"{"reply":""}"#), (200, "not json")] {
        let candidate = SupportClient(endpoint: "https://example.com", code: "x", transport: { @Sendable request in
            (Data(data.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
        })
    let client = try #require(candidate)
        await #expect(throws: (any Error).self) { try await client.reply(messages: [.init(role: "user", text: "Hi")], context: context) }
    }
}

@MainActor @Test func supportCancellationDiscardsLateReplyAndPreventsDuplicateSend() async throws {
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    let candidate = SupportClient(endpoint: "https://example.com", code: "x", transport: { @Sendable request in
        try? await Task.sleep(for: .milliseconds(100)) // Deliberately ignores cancellation: a late response must still be discarded.
        return (Data(#"{"reply":"late"}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    })
    let client = try #require(candidate)
    let model = SupportChatModel(context: context, client: client)
    model.send("First")
    model.send("Duplicate")
    #expect(model.messages.count == 1)
    #expect(model.isSending)
    model.invalidate()
    try await Task.sleep(for: .milliseconds(160))
    #expect(model.messages.isEmpty)
    #expect(!model.isSending)
    model.send("Stale session")
    #expect(model.messages.isEmpty)
}

private actor SupportRequests {
    var counts: [Int] = []
    func receive(_ request: URLRequest) throws -> (Data, HTTPURLResponse) {
        let body = try JSONSerialization.jsonObject(with: request.httpBody!) as! [String: Any]
        counts.append((body["messages"] as! [Any]).count)
        return (Data(#"{"reply":"A useful answer."}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor @Test func supportOnlineHistorySurvivesLocalQuickHelp() async throws {
    let requests = SupportRequests()
    let candidate = SupportClient(endpoint: "https://example.com", code: "test", transport: { request in try await requests.receive(request) })
    let client = try #require(candidate)
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    let model = SupportChatModel(context: context, client: client)
    model.localHelp(.rules)
    model.send("First")
    while model.isSending { await Task.yield() }
    model.localHelp(.state)
    model.send("Follow up")
    while model.isSending { await Task.yield() }
    #expect(await requests.counts == [1, 3])
}

@Test func supportRedirectPolicyNeverForwardsAccessCode() async {
    let original = URL(string: "https://trusted.example/api/support")!
    let session = URLSession(configuration: .ephemeral)
    defer { session.invalidateAndCancel() }
    let task = session.dataTask(with: original)
    for location in ["http://untrusted.example", "https://untrusted.example", "https://trusted.example/new"] {
        var redirected = URLRequest(url: URL(string: location)!)
        redirected.setValue("private-code", forHTTPHeaderField: "x-support-code")
        let response = HTTPURLResponse(url: original, statusCode: 302, httpVersion: nil, headerFields: ["Location": location])!
        let result: URLRequest? = await withCheckedContinuation { continuation in
            SupportRedirectPolicy().urlSession(session, task: task, willPerformHTTPRedirection: response, newRequest: redirected) { continuation.resume(returning: $0) }
        }
        #expect(result == nil)
    }
}

@Test func supportMessageBoundaryMatchesServerUTF16Length() async throws {
    let requests = SupportRequests()
    let candidate = SupportClient(endpoint: "https://example.com", code: "test", transport: { request in try await requests.receive(request) })
    let client = try #require(candidate)
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    // JavaScript measures each supplementary emoji as two UTF-16 code units.
    let accepted = String(repeating: "😀", count: 1000)
    let rejected = String(repeating: "😀", count: 1001)
    #expect(try await client.reply(messages: [.init(role: "user", text: accepted)], context: context) == "A useful answer.")
    await #expect(throws: SupportError.self) {
        try await client.reply(messages: [.init(role: "user", text: rejected)], context: context)
    }
    await #expect(throws: SupportError.self) {
        try await client.reply(messages: [.init(role: "user", text: "Hi"), .init(role: "assistant", text: rejected), .init(role: "user", text: "Next")], context: context)
    }
    #expect(await requests.counts == [1])
}

@MainActor @Test func supportOnlineStartersUseNormalTransport() async throws {
    let requests = SupportRequests()
    let candidate = SupportClient(endpoint: "https://example.com", code: "test", transport: { request in try await requests.receive(request) })
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    let model = SupportChatModel(context: context, client: try #require(candidate))
    for prompt in SupportPrompt.allCases {
        model.quickHelp(prompt)
        while model.isSending { await Task.yield() }
    }
    #expect(await requests.counts == [1, 3, 5])
    #expect(model.messages.filter { $0.role == "assistant" }.allSatisfy { $0.text == "A useful answer." })
}

@MainActor @Test func supportLocalAnswersAreConciseAndConsistent() throws {
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    let rules = context.localAnswer(.rules)
    #expect(rules.split(whereSeparator: \.isWhitespace).count <= 100)
    #expect(rules.lowercased().contains("follow suit"))
    #expect(!rules.hasPrefix("Local"))
    let state = context.localAnswer(.state)
    #expect(state.split(whereSeparator: \.isWhitespace).count <= 65)
    #expect(!state.contains("Game (1)"))
    #expect(!state.contains("seat 0"))
    #expect(!context.localAnswer(.advice).contains("Legal options:"))
    let model = SupportChatModel(context: context, client: nil)
    model.quickHelp(.rules)
    let starterAnswer = model.messages.last?.text
    model.send(SupportPrompt.rules.rawValue)
    #expect(model.messages.last?.text == starterAnswer)
}

@MainActor @Test func supportSixthAndLaterTurnsKeepBoundedAlternatingHistory() async throws {
    let requests = SupportRequests()
    let candidate = SupportClient(endpoint: "https://example.com", code: "test", transport: { request in try await requests.receive(request) })
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    let model = SupportChatModel(context: context, client: try #require(candidate))
    for index in 1...7 {
        model.send("Question \(index)")
        while model.isSending { await Task.yield() }
    }
    #expect(await requests.counts == [1, 3, 5, 7, 9, 9, 9])
    #expect(model.messages.count == 14)
    #expect(model.error == nil)
}

private actor SupportRecoveryRequests {
    var calls = 0
    func receive(_ request: URLRequest) -> (Data, HTTPURLResponse) {
        calls += 1
        let status = calls == 1 ? 503 : 200
        return (Data(#"{"reply":"Try a small bid."}"#.utf8), HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!)
    }
}

@MainActor @Test func supportFailedQuestionStaysVisibleAndRetriesOnce() async throws {
    let requests = SupportRecoveryRequests()
    let candidate = SupportClient(endpoint: "https://example.com", code: "test", transport: { request in await requests.receive(request) })
    let context = try SupportContext(match: Match(deck: supportDeck, dealer: 3), seat: 0)
    let model = SupportChatModel(context: context, client: try #require(candidate))
    model.send("What should I bid?")
    while model.isSending { await Task.yield() }
    #expect(await requests.calls == 1)
    #expect(model.messages.count == 1)
    #expect(model.messages.last?.text == "What should I bid?")
    #expect(model.error != nil)
    model.send("What should I bid?") // Explicit user retry, not an automatic paid request.
    while model.isSending { await Task.yield() }
    #expect(await requests.calls == 2)
    #expect(model.messages.filter { $0.role == "user" }.count == 1)
    #expect(model.messages.last?.text == "Try a small bid.")
}

@Test func supportLongAnswerPreviewKeepsWholeWordsAndShortAnswersIntact() {
    let short = "Follow suit if you can. Otherwise any card is legal, including trump."
    #expect(SupportMessage(role: "assistant", text: short).preview == short)
    let long = Array(repeating: "A longer explanation with whole words.", count: 30).joined(separator: " ")
    let preview = SupportMessage(role: "assistant", text: long).preview
    #expect(preview.split(whereSeparator: \.isWhitespace).count <= 80)
    #expect(preview != long)
    #expect(long.hasPrefix(preview.replacingOccurrences(of: "…", with: "")))
}

@Test func supportLongAnswerPreviewDoesNotCutAtDecimalPoint() {
    let explanation = String(repeating: "The estimate is 3.3 points and remains uncertain ", count: 25)
    let preview = SupportMessage(role: "assistant", text: explanation).preview
    #expect(preview.hasSuffix("…"))
    #expect(explanation.hasPrefix(String(preview.dropLast())))
}

private func supportFinishedFixture() throws -> SupportContext {
    var match = try Match(deck: supportDeck, dealer: 3)
    try match.bid(seat: 0, amount: 9)
    for seat in 1...3 { try match.bid(seat: seat, amount: nil) }
    try match.chooseTrump(seat: 0, suit: .clubs)
    while let seat = match.hand.nextSeat { try match.play(seat: seat, card: #require(match.hand.legalMoves(seat: seat).first)) }
    return try SupportContext(match: match, seat: 0)
}

@MainActor @Test func supportFinishedRulesStarterRetainsIntentThroughFailureAndRetry() async throws {
    let context = try supportFinishedFixture()
    let local = SupportChatModel(context: context, client: nil)
    local.quickHelp(.rules)
    #expect(local.messages.last?.text == context.localAnswer(.rules))
    local.quickHelp(.state)
    #expect(local.messages.last?.text == context.localAnswer(.state))
    #expect(context.localAnswer(.rules) != context.localAnswer(.state))
    let candidate = SupportClient(endpoint: "https://example.com", code: "test", transport: { request in
        (Data(), HTTPURLResponse(url: request.url!, statusCode: 503, httpVersion: nil, headerFields: nil)!)
    })
    let online = SupportChatModel(context: context, client: try #require(candidate))
    online.quickHelp(.rules)
    while online.isSending { await Task.yield() }
    online.send(try #require(online.failedQuestion))
    while online.isSending { await Task.yield() }
    online.useLocalFallback()
    #expect(online.messages.last?.text == context.localAnswer(.rules))
    #expect(online.messages.filter { $0.role == "user" }.count == 1)
}

@Test func supportFinishedNineOutRulesKeepSpecialSettlement() throws {
    let fixture = try supportFinishedFixture()
    for points in [[9, 0], [8, 1]] {
        let settlement = try settle(scores: [0, 0], points: points, bidder: 0, bid: .nineAndOut)
        var object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(fixture)) as! [String: Any]
        var outcome = object["outcome"] as! [String: Any]
        outcome["nineAndOut"] = true
        outcome["contractMade"] = points[0] == 9
        outcome["points"] = points
        outcome["scores"] = settlement.scores
        outcome["winner"] = settlement.winner
        object["outcome"] = outcome
        let context = try JSONDecoder().decode(SupportContext.self, from: JSONSerialization.data(withJSONObject: object))
        let rules = context.localAnswer(.rules)
        #expect(rules.contains("9 and out"))
        #expect(rules.contains("unchanged"))
        #expect(!rules.contains("subtract"))
    }
    #expect(fixture.localAnswer(.rules).contains("missed bidders subtract their bid"))
}

@MainActor @Test func notebookKeepsEditsAndForgetsBlankLines() throws {
    let name = "notebook-test-\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: name))
    defer { defaults.removePersistentDomain(forName: name) }
    let notebook = Notebook(defaults: defaults)
    notebook.toggle("Lead trump early")
    notebook.toggle("The five is worth five")
    #expect(notebook.holds("Lead trump early"))
    notebook.toggle("Lead trump early") // a second tap lets it go
    notebook.notes[0].text = "The five is worth five points"
    notebook.notes.append(.init(text: "  "))
    #expect(Notebook(defaults: defaults).notes.map(\.text) == ["The five is worth five points"])
}

@Test func guestPromptsDecodeWithAndWithoutALink() throws {
    let json = #"[{"text":"Open the album","url":"https://example.com/a?s=%7B1%7D"},{"text":"Tell me a joke"}]"#
    let prompts = try JSONDecoder().decode([MainMenuView.GuestPrompt].self, from: Data(json.utf8))
    #expect(prompts.map(\.text) == ["Open the album", "Tell me a joke"])
    #expect(prompts[0].url?.host == "example.com")
    #expect(prompts[1].url == nil)
    // A chip may carry a short label and ask to be shown as a code; both are optional.
    let short = try JSONDecoder().decode(MainMenuView.GuestPrompt.self, from: Data(#"{"text":"Follow the book club","url":"https://example.com/b","label":"Book club","code":true}"#.utf8))
    #expect(short.label == "Book club" && short.code == true && prompts[0].label == nil)
    #expect(GuestCodeCard.code(for: "https://example.com/b") != nil)
}

@Test func guestNoteDecodesAndTheScallopedCardHasAnEdge() throws {
    let json = #"{"name":"Ada","greeting":"Ada,","body":"Thank you.","signoff":"C"}"#
    #expect(try JSONDecoder().decode(GuestNote.self, from: Data(json.utf8)).signoff == "C")
    let rect = CGRect(x: 0, y: 0, width: 200, height: 300)
    // The bumps reach the frame; an inset card stays inside it.
    #expect(abs(Scalloped(bump: 16).path(in: rect).boundingRect.width - 200) < 1)
    #expect(Scalloped(bump: 16).inset(by: 10).path(in: rect).boundingRect.width < 185)
}
