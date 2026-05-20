import XCTest
@testable import VoiceInputMac

final class DictionaryLearningSuggesterTests: XCTestCase {
    func testSuggestsTechnicalPhraseCorrectionWithSharedPrefixExpansion() {
        let original = "帮我写一下 Swift You Eye 和 Whisper.cpp 的集成方案。"
        let edited = "帮我写一下 SwiftUI 和 Whisper.cpp 的集成方案。"

        let suggestion = DictionaryLearningSuggester().suggestion(originalText: original, editedText: edited)

        XCTAssertEqual(suggestion?.spoken, "Swift You Eye")
        XCTAssertEqual(suggestion?.written, "SwiftUI")
    }

    func testSuggestsSimplePhraseCorrection() {
        let original = "帮我分析一下 Transformer Xr 的模型。"
        let edited = "帮我分析一下 Transformer-XL 的模型。"

        let suggestion = DictionaryLearningSuggester().suggestion(originalText: original, editedText: edited)

        XCTAssertEqual(suggestion?.spoken, "Transformer Xr")
        XCTAssertEqual(suggestion?.written, "Transformer-XL")
    }

    func testDoesNotSuggestWhenThereIsNoEdit() {
        let text = "我们下周一下午三点开会。"

        let suggestion = DictionaryLearningSuggester().suggestion(originalText: text, editedText: text)

        XCTAssertNil(suggestion)
    }

    func testDoesNotSuggestLargeSentenceRewrite() {
        let original = "这个功能不好用。"
        let edited = "这个功能目前还有优化空间，可以后续再看。"

        let suggestion = DictionaryLearningSuggester().suggestion(originalText: original, editedText: edited)

        XCTAssertNil(suggestion)
    }
}
