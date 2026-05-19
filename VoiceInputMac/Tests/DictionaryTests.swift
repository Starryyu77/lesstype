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

    func testDictionaryNormalizerFixesDictationHomophonesAndSpokenPhrases() {
        let raw = "这个差路依然不太正常还有一个问题就是他好像没有办法去对我们说的话进行一个整理"
        let normalized = DictionaryNormalizer().normalize(raw, entries: DictionaryStore.defaultEntries)
        XCTAssertTrue(normalized.contains("插入"))
        XCTAssertFalse(normalized.contains("差路"))
        XCTAssertFalse(normalized.contains("进行一个整理"))
        XCTAssertTrue(normalized.contains("无法"))
    }
}
