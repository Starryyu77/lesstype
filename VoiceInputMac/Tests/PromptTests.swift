import XCTest
@testable import VoiceInputMac

final class PromptTests: XCTestCase {
    func testPromptBuilderFillsVariables() throws {
        let prompt = try PromptBuilder().build(
            mode: .dictation,
            activeApp: "WeChat",
            windowTitle: "Chat",
            selectedText: "",
            contextBefore: "",
            personalDictionary: DictionaryStore.defaultEntries,
            styleProfile: StyleProfileStore.defaultProfiles.first,
            rawTranscript: "呃我们下周一开会"
        )

        XCTAssertTrue(prompt.system.contains("语音输入法的文本后处理器"))
        XCTAssertTrue(prompt.user.contains("当前 App: WeChat"))
        XCTAssertTrue(prompt.user.contains("Typeless"))
        XCTAssertTrue(prompt.user.contains("呃我们下周一开会"))
    }
}

