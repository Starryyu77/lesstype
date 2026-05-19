import XCTest
@testable import VoiceInputMac

final class DictionaryTests: XCTestCase {
    func testDictionaryNormalizerRewritesCommonTerms() {
        let raw = "帮我写一下这个 cursor 里面 swift ui 和 whisper 点 cpp 的集成方案"
        let normalized = DictionaryNormalizer().normalize(raw, entries: DictionaryStore.defaultEntries)
        XCTAssertTrue(normalized.contains("Cursor"))
        XCTAssertTrue(normalized.contains("SwiftUI"))
        XCTAssertTrue(normalized.contains("whisper.cpp"))
    }
}

