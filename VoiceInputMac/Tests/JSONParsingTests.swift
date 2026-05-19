import XCTest
@testable import VoiceInputMac

final class JSONParsingTests: XCTestCase {
    func testParsesStrictJSON() {
        let raw = #"{"action":"insert","text":"你好","detected_language":"zh","format":"plain","confidence":0.9,"warnings":[]}"#
        let action = JSONRepair.parseAction(from: raw)
        XCTAssertEqual(action?.action, "insert")
        XCTAssertEqual(action?.text, "你好")
    }

    func testExtractsJSONFromExtraText() {
        let raw = #"好的：{"action":"show_panel","text":"结果","detected_language":"zh","format":"plain","confidence":0.4,"warnings":["low_confidence"]}谢谢"#
        let action = JSONRepair.parseAction(from: raw)
        XCTAssertEqual(action?.action, "show_panel")
        XCTAssertEqual(action?.warnings, ["low_confidence"])
    }
}

