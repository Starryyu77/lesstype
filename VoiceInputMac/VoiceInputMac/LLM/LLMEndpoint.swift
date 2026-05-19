import Foundation

struct LLMEndpoint: Equatable {
    let providerID: LLMProviderID
    let displayName: String
    let baseURL: String
    let path: String
    let model: String
    let temperature: Double
    let timeoutSeconds: Int
    let keychainAccount: String
    let authHeader: String
    let authScheme: String
    let requiresAPIKey: Bool
    let extraHeaders: [String: String]

    static func selected(from config: AppConfig) -> LLMEndpoint {
        switch LLMProviderID(rawValue: config.llmProvider) ?? .volcengineArk {
        case .volcengineArk:
            return LLMEndpoint(
                providerID: .volcengineArk,
                displayName: "豆包 / 火山方舟",
                baseURL: config.arkBaseURL,
                path: "chat/completions",
                model: config.arkModel,
                temperature: config.arkTemperature,
                timeoutSeconds: config.arkTimeoutSeconds,
                keychainAccount: "ark_api_key",
                authHeader: "Authorization",
                authScheme: "Bearer",
                requiresAPIKey: true,
                extraHeaders: [:]
            )
        case .customOpenAICompatible:
            return LLMEndpoint(
                providerID: .customOpenAICompatible,
                displayName: "自定义 OpenAI-compatible",
                baseURL: config.customLLMBaseURL,
                path: config.customLLMPath,
                model: config.customLLMModel,
                temperature: config.arkTemperature,
                timeoutSeconds: config.arkTimeoutSeconds,
                keychainAccount: "custom_llm_api_key",
                authHeader: config.customLLMAuthHeader,
                authScheme: config.customLLMAuthScheme,
                requiresAPIKey: config.customLLMRequiresAPIKey,
                extraHeaders: Self.decodeHeaders(config.customLLMExtraHeadersJSON)
            )
        }
    }

    var trimmedModel: String {
        model.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedBaseURL: String {
        baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func decodeHeaders(_ raw: String) -> [String: String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, let data = trimmed.data(using: .utf8) else {
            return [:]
        }
        return (try? JSONDecoder().decode([String: String].self, from: data)) ?? [:]
    }
}

