import XCTest
@testable import VoiceInputMac

final class WhisperCliServiceTests: XCTestCase {
    func testTranscribeThrowsWhenWhisperReportsEmptyTestModel() async throws {
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceinput-whisper-test-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: tempDir) }

        let fakeCLI = tempDir.appendingPathComponent("fake-whisper-cli")
        try """
        #!/bin/sh
        echo "whisper_model_load: WARN no tensors loaded from model file - assuming empty model for testing" 1>&2
        exit 0
        """.write(to: fakeCLI, atomically: true, encoding: .utf8)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: fakeCLI.path)

        let audioURL = tempDir.appendingPathComponent("audio.wav")
        try Data(repeating: 1, count: 128).write(to: audioURL)
        let modelURL = tempDir.appendingPathComponent("model.bin")
        try Data(repeating: 1, count: 128).write(to: modelURL)

        do {
            _ = try await WhisperCliService().transcribe(
                audioURL: audioURL,
                options: ASROptions(
                    language: "zh",
                    useMetal: false,
                    useCoreML: false,
                    maxSegmentSeconds: 1,
                    modelPath: modelURL.path,
                    cliCommand: fakeCLI.path
                )
            )
            XCTFail("Expected transcribe to reject an empty whisper.cpp test model")
        } catch AppError.asrFailed(let message) {
            XCTAssertTrue(message.contains("测试模型"))
        }
    }

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
