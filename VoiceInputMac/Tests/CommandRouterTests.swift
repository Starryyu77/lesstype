import XCTest
@testable import VoiceInputMac

final class CommandRouterTests: XCTestCase {
    func testCancelCommandRoutesToSystemCommand() {
        let route = CommandRouter().route(rawTranscript: "算了不要了", hasSelectedText: false)
        XCTAssertEqual(route.type, .systemCommand)
    }

    func testEditCommandRequiresSelection() {
        let withSelection = CommandRouter().route(rawTranscript: "改短一点", hasSelectedText: true)
        let withoutSelection = CommandRouter().route(rawTranscript: "改短一点", hasSelectedText: false)
        XCTAssertEqual(withSelection.type, .editSelection)
        XCTAssertEqual(withoutSelection.type, .dictation)
    }
}

