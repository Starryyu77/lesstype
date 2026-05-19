import XCTest
@testable import VoiceInputMac

final class AppConfigTests: XCTestCase {
    func testMissingNewFieldsDecodeToDefaults() throws {
        let oldJSON = #"{"llmProvider":"volcengine_ark","arkModel":"doubao-test","saveHistory":false}"#
        let config = try JSONDecoder().decode(AppConfig.self, from: Data(oldJSON.utf8))

        XCTAssertEqual(config.llmProvider, "volcengine_ark")
        XCTAssertEqual(config.arkModel, "doubao-test")
        XCTAssertFalse(config.saveHistory)
        XCTAssertEqual(config.customLLMBaseURL, "http://127.0.0.1:8000/v1")
        XCTAssertEqual(config.customLLMPath, "chat/completions")
    }

    func testMigratesLegacyOptionSpaceDefaultsToReliableFallback() throws {
        var config = try JSONDecoder().decode(
            AppConfig.self,
            from: Data(#"{"dictationHotkey":"Option+Space","editSelectionHotkey":"Option+Shift+Space"}"#.utf8)
        )
        config.migrateLegacyHotkeyDefaults()

        XCTAssertEqual(config.dictationHotkey, "Control+Option+A")
        XCTAssertEqual(config.editSelectionHotkey, "Control+Option+Shift+A")
    }
}
