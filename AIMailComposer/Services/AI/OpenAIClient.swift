import Foundation

/// Speaks the OpenAI chat-completions protocol. Also serves any
/// OpenAI-compatible endpoint via `.openaiCompatible` — same wire format,
/// different base URL.
final class OpenAIClient: AIClient {
    let provider: AIProvider
    private let apiKey: String
    private let model: String

    init(provider: AIProvider = .openai, apiKey: String, model: String) {
        self.provider = provider
        self.apiKey = apiKey
        self.model = model
    }

    func stream(systemPrompt: String, userMessage: String) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let base = provider.effectiveBaseURL
                    guard !base.isEmpty, let url = URL(string: "\(base)/chat/completions") else {
                        throw AIClientError.requestFailed("Missing or invalid \(provider.displayName) base URL. Check Settings → API Keys.")
                    }
                    var request = URLRequest(url: url)
                    request.httpMethod = "POST"
                    request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
                    request.setValue("application/json", forHTTPHeaderField: "content-type")

                    let body: [String: Any] = [
                        "model": model,
                        "stream": true,
                        "messages": [
                            ["role": "system", "content": systemPrompt],
                            ["role": "user", "content": userMessage],
                        ],
                    ]
                    request.httpBody = try JSONSerialization.data(withJSONObject: body)

                    let (bytes, response) = try await URLSession.shared.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw AIClientError.requestFailed("No HTTP response")
                    }
                    guard http.statusCode == 200 else {
                        var errorBody = ""
                        for try await line in bytes.lines { errorBody += line + "\n" }
                        throw AIClientError.requestFailed("HTTP \(http.statusCode): \(errorBody)")
                    }

                    for try await line in bytes.lines {
                        try Task.checkCancellation()
                        switch OpenAICompatibleStream.parse(line: line) {
                        case .delta(let text): continuation.yield(text)
                        case .done: continuation.finish(); return
                        case .none: continue
                        }
                    }
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in task.cancel() }
        }
    }
}
