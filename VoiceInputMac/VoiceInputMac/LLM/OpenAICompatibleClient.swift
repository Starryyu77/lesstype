import Foundation

final class OpenAICompatibleClient: LLMProvider {
    private let configProvider: () -> AppConfig
    private let keychainStore: KeychainStore
    private let apiKeyProvider: (() throws -> String?)?
    private let session: URLSession

    init(
        configProvider: @escaping () -> AppConfig,
        keychainStore: KeychainStore,
        apiKeyProvider: (() throws -> String?)? = nil,
        session: URLSession = .shared
    ) {
        self.configProvider = configProvider
        self.keychainStore = keychainStore
        self.apiKeyProvider = apiKeyProvider
        self.session = session
    }

    func complete(systemPrompt: String, userPrompt: String, options: LLMOptions) async throws -> LLMResult {
        let endpoint = LLMEndpoint.selected(from: configProvider())
        guard !endpoint.trimmedBaseURL.isEmpty else {
            throw AppError.llmFailed("\(endpoint.displayName) base URL is empty")
        }
        guard !endpoint.trimmedModel.isEmpty else {
            throw AppError.llmFailed("\(endpoint.displayName) model is empty")
        }

        let apiKey = try loadAPIKey(for: endpoint)
        if endpoint.requiresAPIKey && apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw AppError.llmAPIKeyMissing
        }

        let start = Date()
        var lastError: Error?
        for attempt in 0..<3 {
            do {
                let text = try await requestCompletion(
                    endpoint: endpoint,
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
        throw lastError ?? AppError.llmFailed("Unknown \(endpoint.displayName) error")
    }

    private func loadAPIKey(for endpoint: LLMEndpoint) throws -> String {
        if let apiKey = try apiKeyProvider?() {
            return apiKey
        }
        return try keychainStore.getSecret(account: endpoint.keychainAccount) ?? ""
    }

    private func requestCompletion(
        endpoint: LLMEndpoint,
        apiKey: String,
        systemPrompt: String,
        userPrompt: String,
        options: LLMOptions
    ) async throws -> String {
        let url = try completionURL(endpoint: endpoint)
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = TimeInterval(options.timeoutSeconds)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        for (name, value) in endpoint.extraHeaders {
            if !isSensitiveHeader(name) {
                request.setValue(value, forHTTPHeaderField: name)
            }
        }

        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        let header = endpoint.authHeader.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty, !header.isEmpty {
            let scheme = endpoint.authScheme.trimmingCharacters(in: .whitespacesAndNewlines)
            let value = scheme.isEmpty ? trimmedKey : "\(scheme) \(trimmedKey)"
            request.setValue(value, forHTTPHeaderField: header)
        }

        var payload: [String: Any] = [
            "model": endpoint.trimmedModel,
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
            throw AppError.llmFailed("\(endpoint.displayName) response was not HTTP")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw AppError.llmFailed("\(endpoint.displayName) HTTP \(http.statusCode): \(sanitize(body))")
        }

        let root = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let choices = root?["choices"] as? [[String: Any]]
        let message = choices?.first?["message"] as? [String: Any]
        if let content = message?["content"] as? String {
            return content
        }
        throw AppError.llmFailed("\(endpoint.displayName) response missing choices[0].message.content")
    }

    private func completionURL(endpoint: LLMEndpoint) throws -> URL {
        guard var components = URLComponents(string: endpoint.trimmedBaseURL) else {
            throw AppError.llmFailed("Invalid \(endpoint.displayName) base URL")
        }
        let basePath = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let relativePath = endpoint.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([basePath, relativePath].filter { !$0.isEmpty }.joined(separator: "/"))
        guard let url = components.url else {
            throw AppError.llmFailed("Invalid \(endpoint.displayName) completion URL")
        }
        return url
    }

    private func isSensitiveHeader(_ name: String) -> Bool {
        let normalized = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalized == "authorization" ||
            normalized.contains("api-key") ||
            normalized.contains("apikey") ||
            normalized.contains("token") ||
            normalized.contains("secret") ||
            normalized.contains("auth")
    }

    private func sanitize(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"Bearer\s+[A-Za-z0-9._\-]+"#, with: "Bearer <redacted>", options: .regularExpression)
            .replacingOccurrences(of: #""api[_-]?key"\s*:\s*"[^"]+""#, with: #""api_key":"<redacted>""#, options: .regularExpression)
    }
}
