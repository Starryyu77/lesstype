import Foundation

struct LLMAction: Codable, Equatable {
    let action: String
    let text: String
    let detected_language: String
    let format: String
    let confidence: Double
    let warnings: [String]

    static func insert(_ text: String) -> LLMAction {
        LLMAction(action: "insert", text: text, detected_language: "unknown", format: "plain", confidence: 0.7, warnings: [])
    }
}

struct CommandRoute: Codable, Equatable {
    let type: String
    let command: String
    let confidence: Double
}

