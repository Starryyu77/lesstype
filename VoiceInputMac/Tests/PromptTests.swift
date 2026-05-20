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

        XCTAssertTrue(prompt.system.contains("本地语音输入助手的文本改写器"))
        XCTAssertTrue(prompt.user.contains("当前 App: WeChat"))
        XCTAssertTrue(prompt.user.contains("Typeless"))
        XCTAssertTrue(prompt.user.contains("呃我们下周一开会"))
    }

    func testDictationPromptAsksForSmartRewriteNotTranscript() throws {
        let prompt = try PromptBuilder().build(
            mode: .dictation,
            activeApp: "WeChat",
            windowTitle: "Chat",
            selectedText: "",
            contextBefore: "",
            personalDictionary: DictionaryStore.defaultEntries,
            styleProfile: StyleProfileStore.defaultProfiles.first,
            rawTranscript: "帮我跟他说一下就是这个需求我今天做不完可能要明天上午给你"
        )

        XCTAssertTrue(prompt.system.contains("不要输出逐字稿"))
        XCTAssertTrue(prompt.system.contains("忠于事实的智能改写"))
        XCTAssertTrue(prompt.system.contains("指令外壳"))
        XCTAssertTrue(prompt.system.contains("保留有语义的开头和主体"))
        XCTAssertTrue(prompt.system.contains("AI/代码/工作工具"))
        XCTAssertTrue(prompt.system.contains("不要把“集成方案”“基础方案”“实现方案”“调试计划”等任务名随意替换成近义词"))
        XCTAssertTrue(prompt.system.contains("不要写成“Cursor里面SwiftUI和Whisper.cpp”"))
        XCTAssertTrue(prompt.system.contains("\"action\": \"insert | replace_selection | show_panel | noop\""))
        XCTAssertTrue(prompt.system.contains("这个需求我今天做不完，可能要明天上午给你。"))
        XCTAssertTrue(prompt.system.contains("帮我写一下 Cursor 里 SwiftUI 和 Whisper.cpp 的集成方案。"))
    }

    func testEditSelectionPromptHandlesToneAndReplacementAction() throws {
        let prompt = try PromptBuilder().build(
            mode: .editSelection,
            activeApp: "Mail",
            windowTitle: "Draft",
            selectedText: "这个功能不好用。",
            contextBefore: "",
            personalDictionary: DictionaryStore.defaultEntries,
            styleProfile: StyleProfileStore.defaultProfiles.first,
            rawTranscript: "改得委婉一点"
        )

        XCTAssertTrue(prompt.system.contains("action 默认使用 replace_selection"))
        XCTAssertTrue(prompt.system.contains("改得委婉一点"))
        XCTAssertTrue(prompt.system.contains("不要添加原文没有的信息"))
        XCTAssertTrue(prompt.user.contains("选中文本:\n这个功能不好用。"))
    }
}
