import XCTest
@testable import VoiceInputMac

final class WhisperCliServiceTests: XCTestCase {
    func testCleanDropsWhisperBackendLogs() {
        let rawOutput = """
        load_backend: loaded BLAS backend from /opt/homebrew/Cellar/ggml/0.12.0/libexec/libggml-blas.so
        ggml_metal_device_init: tensor API disabled for pre-M5 and pre-A19 devices
        ggml_metal_library_init: using embedded metal library
        ggml_metal_free: deallocating
        """

        XCTAssertEqual(WhisperCliService.clean(stdout: rawOutput), "")
    }

    func testCleanKeepsTranscriptLines() {
        let rawOutput = """
        load_backend: loaded MTL backend from /opt/homebrew/Cellar/ggml/0.12.0/libexec/libggml-metal.so
        [00:00:00.000 --> 00:00:01.000] 你好，今天开会。
        """

        XCTAssertEqual(WhisperCliService.clean(stdout: rawOutput), "你好，今天开会。")
    }
}
