import XCTest
@testable import VoiceInputMac

final class AccessibilityInjectorTests: XCTestCase {
    func testAXTextRangeReplacementInsertsAtCaret() {
        let value = "前文后文"
        let range = CFRange(location: "前文".utf16.count, length: 0)

        let result = AXTextRangeReplacement.replacing(value, range: range, with: "插入")

        XCTAssertEqual(result, "前文插入后文")
    }

    func testAXTextRangeReplacementReplacesSelection() {
        let value = "这个功能不好用。"
        let range = CFRange(location: "这个功能".utf16.count, length: "不好用".utf16.count)

        let result = AXTextRangeReplacement.replacing(value, range: range, with: "还需要优化")

        XCTAssertEqual(result, "这个功能还需要优化。")
    }

    func testAXTextRangeReplacementRejectsInvalidRange() {
        let value = "短文本"
        let range = CFRange(location: 10, length: 1)

        let result = AXTextRangeReplacement.replacing(value, range: range, with: "插入")

        XCTAssertNil(result)
    }
}
