import AppKit
import XCTest
@testable import VoiceInputMac

final class HotKeyTests: XCTestCase {
    func testParsesDefaultHotkeys() {
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Fn+A"),
            HotKeyDefinition(keyCode: 0, modifiers: [.function])
        )
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Fn+Shift+A"),
            HotKeyDefinition(keyCode: 0, modifiers: [.function, .shift])
        )
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Option+Space"),
            HotKeyDefinition(keyCode: 49, modifiers: [.option])
        )
    }

    func testRejectsUnknownKey() {
        XCTAssertNil(HotKeyDefinition(rawValue: "Option+NotAKey"))
    }
}
