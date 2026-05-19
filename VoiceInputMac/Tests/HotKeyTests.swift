import AppKit
import XCTest
@testable import VoiceInputMac

final class HotKeyTests: XCTestCase {
    func testParsesDefaultHotkeys() {
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Control+Option+A"),
            HotKeyDefinition(keyCode: 0, modifiers: [.control, .option])
        )
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Control+Option+Shift+A"),
            HotKeyDefinition(keyCode: 0, modifiers: [.control, .option, .shift])
        )
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

    func testParsesReliableFallbackHotkeys() {
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Control+Option+A"),
            HotKeyDefinition(keyCode: 0, modifiers: [.control, .option])
        )
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Control+Option+Shift+A"),
            HotKeyDefinition(keyCode: 0, modifiers: [.control, .option, .shift])
        )
    }

    func testBuildsHotkeyFromCapturedEvent() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control, .option, .numericPad],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )

        XCTAssertEqual(
            event.flatMap(HotKeyDefinition.from(event:)),
            HotKeyDefinition(keyCode: 0, modifiers: [.control, .option])
        )
        XCTAssertEqual(event.flatMap(HotKeyDefinition.from(event:))?.displayName, "Control+Option+A")
    }

    func testMatchesControlOptionEventWithExtraFlags() {
        let event = NSEvent.keyEvent(
            with: .keyDown,
            location: .zero,
            modifierFlags: [.control, .option, .numericPad],
            timestamp: 0,
            windowNumber: 0,
            context: nil,
            characters: "a",
            charactersIgnoringModifiers: "a",
            isARepeat: false,
            keyCode: 0
        )

        XCTAssertEqual(event.flatMap(HotKeyDefinition.from(event:))?.displayName, "Control+Option+A")
        XCTAssertEqual(HotKeyDefinition(rawValue: "Control+Option+A")?.matches(event!), true)
    }

    func testBuildsHotkeyFromCGEventWithFnFlag() {
        let event = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true)
        event?.flags = [.maskSecondaryFn, .maskControl]

        XCTAssertEqual(
            event.flatMap { HotKeyDefinition.from(cgEvent: $0, type: .keyDown) },
            HotKeyDefinition(keyCode: 0, modifiers: [.function, .control])
        )
        XCTAssertEqual(event.flatMap { HotKeyDefinition.from(cgEvent: $0, type: .keyDown) }?.displayName, "Fn+Control+A")
    }

    func testParsesFunctionDigitAndRawKeyNames() {
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Control+F12"),
            HotKeyDefinition(keyCode: 111, modifiers: [.control])
        )
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Command+1"),
            HotKeyDefinition(keyCode: 18, modifiers: [.command])
        )
        XCTAssertEqual(
            HotKeyDefinition(rawValue: "Option+Key123"),
            HotKeyDefinition(keyCode: 123, modifiers: [.option])
        )
    }
}
