import Foundation

enum PipelineFallback {
    static func actionWhenLLMUnavailable(mode: PipelineMode, transcript: String, language: String) -> LLMAction {
        LLMAction(
            action: mode == .editSelection ? "replace_selection" : "insert",
            text: transcript,
            detected_language: language == "en" ? "en" : "zh",
            format: "plain",
            confidence: 0.7,
            warnings: ["llm_unavailable_fallback_to_asr"]
        )
    }
}

