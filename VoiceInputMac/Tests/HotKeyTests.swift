import AppKit
import XCTest
@testable import VoiceInputMac

final class HotKeyTests: XCTestCase {
    func testParsesDefaultHotkeys() {
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Option+Space"),
            HotKeyDefinition(keyCode: 49, modifiers: [.option])
        )
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Option+Shift+Space"),
            HotKeyDefinition(keyCode: 49, modifiers: [.option, .shift])
        )
    }

    func testRejectsUnknownKey() {
        XCTAssertNil(HotKeyDefinition(rawValue: "Option+NotAKey"))
    }
}

