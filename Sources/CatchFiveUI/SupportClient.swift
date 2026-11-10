import Foundation

struct SupportMessage: Codable, Equatable, Sendable {
    let role: String
    let text: String

    /// JavaScript's string.length uses UTF-16 code units, including two for supplementary emoji.
    static func fits(_ text: String) -> Bool { text.utf16.count <= 2000 }

    static func historyText(_ text: String) -> String {
        var length = 0
        return String(text.prefix { character in
            length += String(character).utf16.count
            return length <= 2000
        })
    }
}

enum SupportError: LocalizedError {
    case unavailable, invalidRequest
    var errorDescription: String? {
        switch self {
        case .unavailable: "Online support is unavailable. Local help is still available."
        case .invalidRequest: "Keep questions under 2,000 characters. Start a new chat after five questions."
        }
    }
}

/// Authenticated redirects are refused, including HTTPS redirects to another host.
final class SupportRedirectPolicy: NSObject, URLSessionTaskDelegate, Sendable {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping @Sendable (URLRequest?) -> Void) {
        completionHandler(nil)
    }
}

struct SupportClient: Sendable {
    typealias Transport = @Sendable (URLRequest) async throws -> (Data, HTTPURLResponse)
    private let endpoint: URL
    private let code: String
    private let transport: Transport

    init?(endpoint: String, code: String, transport: Transport? = nil) {
        guard let url = URL(string: endpoint), url.scheme?.lowercased() == "https", let host = url.host, !host.isEmpty,
              url.user == nil, url.password == nil, url.query == nil, url.fragment == nil,
              !code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, code.count <= 256,
              !code.contains("\r"), !code.contains("\n") else { return nil }
        self.endpoint = url
        self.code = code
        self.transport = transport ?? { request in
            let config = URLSessionConfiguration.ephemeral
            config.httpCookieStorage = nil
            config.urlCache = nil
            let session = URLSession(configuration: config, delegate: SupportRedirectPolicy(), delegateQueue: nil)
            defer { session.invalidateAndCancel() }
            let (data, response) = try await session.data(for: request)
            guard let response = response as? HTTPURLResponse else { throw SupportError.unavailable }
            return (data, response)
        }
    }

    func reply(messages: [SupportMessage], context: SupportContext) async throws -> String {
        guard !messages.isEmpty, messages.count <= 9, messages.count % 2 == 1,
              messages.enumerated().allSatisfy({ i, message in
                  message.role == (i % 2 == 0 ? "user" : "assistant") && !message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && SupportMessage.fits(message.text)
              }) else { throw SupportError.invalidRequest }
        struct Request: Encodable { let messages: [SupportMessage]; let context: SupportContext }
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(code, forHTTPHeaderField: "x-support-code")
        request.httpBody = try JSONEncoder().encode(Request(messages: messages, context: context))
        guard request.httpBody!.count <= 48 * 1024 else { throw SupportError.invalidRequest }
        let (data, response) = try await transport(request)
        try Task.checkCancellation()
        guard response.statusCode == 200, data.count <= 48 * 1024 else { throw SupportError.unavailable }
        struct Reply: Decodable { let reply: String }
        guard let reply = try? JSONDecoder().decode(Reply.self, from: data).reply,
              !reply.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, reply.utf16.count <= 12000 else { throw SupportError.unavailable }
        return reply
    }
}
