import Foundation

protocol LLMProvider {
    func complete(systemPrompt: String, userPrompt: String, options: LLMOptions) async throws -> LLMResult
}

struct LLMOptions {
    let model: String
    let temperature: Double
    let timeoutSeconds: Int
    let responseFormat: String
}

struct LLMResult {
    let rawText: String
    let parsed: LLMAction?
    let durationMs: Int
}

