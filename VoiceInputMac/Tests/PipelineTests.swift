import XCTest
@testable import VoiceInputMac

final class PipelineTests: XCTestCase {
    func testPipelineFallbackUsesASRWhenLLMUnavailable() {
        let action = PipelineFallback.actionWhenLLMUnavailable(
            mode: .dictation,
            transcript: "本地识别文本",
            language: "zh"
        )
        XCTAssertEqual(action.action, "insert")
        XCTAssertEqual(action.text, "本地识别文本")
        XCTAssertTrue(action.warnings.contains("llm_unavailable_fallback_to_asr"))
    }

    func testEditFallbackReplacesSelection() {
        let action = PipelineFallback.actionWhenLLMUnavailable(
            mode: .editSelection,
            transcript: "更正式一点",
            language: "zh"
        )
        XCTAssertEqual(action.action, "replace_selection")
    }
}

