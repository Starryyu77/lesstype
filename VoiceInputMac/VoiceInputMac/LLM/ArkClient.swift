import Foundation

final class ArkClient: LLMProvider {
    private let configProvider: () -> AppConfig
    private let keychainStore: KeychainStore
    private let session: URLSession

    init(configProvider: @escaping () -> AppConfig, keychainStore: KeychainStore, session: URLSession = .shared) {
        self.configProvider = configProvider
        self.keychainStore = keychainStore
        self.session = session
    }

    func complete(systemPrompt: String, userPrompt: String, options: LLMOptions) async throws -> LLMResult {
        let config = configProvider()
        guard let apiKey = try keychainStore.getSecret(account: "ark_api_key"),
              !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.llmAPIKeyMissing
        }
        guard !options.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw AppError.llmFailed("Ark model is empty")
        }

        let start = Date()
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let text = try await requestCompletion(
                    baseURL: config.arkBaseURL,
                    apiKey: apiKey,
                    systemPrompt: systemPrompt,
                    userPrompt: userPrompt,
                    options: options
                )
                return LLMResult(
                    rawText: text,
                    parsed: JSONRepair.parseAction(from: text),
                    durationMs: Int(Date().timeIntervalSince(start) * 1000)
                )
            } catch {
                lastError = error
                if attempt < 2 {
                    try await Task.sleep(nanoseconds: UInt64(300 * (attempt + 1)) * 1_000_000)
                }
            }
        }
        throw lastError ?? AppError.llmFailed("Unknown Ark error")
    }

    private func requestCompletion(
        baseURL: String,
        apiKey: String,
        systemPrompt: String,
        userPrompt: String,
        options: LLMOptions
    ) async throws -> String {
        guard var components = URLComponents(string: baseURL) else {
            throw AppError.llmFailed("Invalid Ark base URL")
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, "chat/completions"].filter { !$0.isEmpty }.joined(separator: "/"))
        guard let url = components.url else {
            throw AppError.llmFailed("Invalid Ark completion URL")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(options.timeoutSeconds)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        var payload: [String: Any] = [
            "model": options.model,
            "temperature": options.temperature,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ]
        ]
        if options.responseFormat == "json_object" {
            payload["response_format"] = ["type": "json_object"]
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw AppError.llmFailed("Ark response was not HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AppError.llmFailed("Ark HTTP \(http.statusCode): \(sanitize(body))")
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = root?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        if let content = message?["content"] as? String {
            return content
        }
        throw AppError.llmFailed("Ark response missing choices[0].message.content")
    }

    private func sanitize(_ text: String) -> String {
        text.replacingOccurrences(of: #"Bearer\s+[A-Za-z0-9._\-]+"#, with: "Bearer <redacted>", options: .regularExpression)
    }
}

