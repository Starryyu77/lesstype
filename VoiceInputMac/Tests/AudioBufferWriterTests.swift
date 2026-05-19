import Foundation
import XCTest
@testable import VoiceInputMac

final class AudioBufferWriterTests: XCTestCase {
    func testWritesMono16WAVHeaderAndSamples() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceinput-audio-writer-test-\(UUID().uuidString)")
            .appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }

        try AudioBufferWriter.writeMono16WAV(samples: [0, 0.5, -0.5, 1], inputSampleRate: 16_000, to: url)

        let data = try Data(contentsOf: url)
        XCTAssertEqual(String(data: data.prefix(4), encoding: .ascii), "RIFF")
        XCTAssertEqual(String(data: data.dropFirst(8).prefix(4), encoding: .ascii), "WAVE")
        XCTAssertEqual(String(data: data.dropFirst(36).prefix(4), encoding: .ascii), "data")
        XCTAssertEqual(data.count, 44 + 4 * 2)
    }
}
