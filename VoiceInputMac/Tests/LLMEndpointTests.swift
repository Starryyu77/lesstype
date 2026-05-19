import XCTest
@testable import VoiceInputMac

final class LLMEndpointTests: XCTestCase {
    func testArkEndpointUsesArkDefaults() {
        var config = AppConfig()
        config.arkModel = "doubao-test"
        let endpoint = LLMEndpoint.selected(from: config)
        XCTAssertEqual(endpoint.providerID, .volcengineArk)
        XCTAssertEqual(endpoint.baseURL, "https://ark.cn-beijing.volces.com/api/v3")
        XCTAssertEqual(endpoint.path, "chat/completions")
        XCTAssertEqual(endpoint.model, "doubao-test")
        XCTAssertEqual(endpoint.keychainAccount, "ark_api_key")
        XCTAssertTrue(endpoint.requiresAPIKey)
    }

    func testCustomEndpointCanUseLocalOpenAICompatibleServerWithoutKey() {
        var config = AppConfig()
        config.llmProvider = LLMProviderID.customOpenAICompatible.rawValue
        config.customLLMBaseURL = "http://127.0.0.1:8000/v1"
        config.customLLMPath = "chat/completions"
        config.customLLMModel = "my-local-model"
        config.customLLMRequiresAPIKey = false
        config.customLLMExtraHeadersJSON = #"{"X-Client":"VoiceInputMac"}"#

        let endpoint = LLMEndpoint.selected(from: config)
        XCTAssertEqual(endpoint.providerID, .customOpenAICompatible)
        XCTAssertEqual(endpoint.model, "my-local-model")
        XCTAssertEqual(endpoint.keychainAccount, "custom_llm_api_key")
        XCTAssertFalse(endpoint.requiresAPIKey)
        XCTAssertEqual(endpoint.extraHeaders["X-Client"], "VoiceInputMac")
    }
}

