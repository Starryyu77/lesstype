import AppKit
import XCTest
@testable import VoiceInputMac

final class PasteboardTests: XCTestCase {
    func testClipboardSnapshotRestoresStringContent() {
        let pasteboard = NSPasteboard.general
        let original = "voiceinput-original-\(UUID().uuidString)"
        pasteboard.clearContents()
        pasteboard.setString(original, forType: .string)

        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString("temporary-inserted-text", forType: .string)
        snapshot.restore(to: pasteboard)

        XCTAssertEqual(pasteboard.string(forType: .string), original)
    }
}

