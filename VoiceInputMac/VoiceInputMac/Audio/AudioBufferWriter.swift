import Foundation

enum AudioBufferWriter {
    static func makeTemporaryWAVURL() -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent("voiceinput-\(UUID().uuidString)")
            .appendingPathExtension("wav")
    }
}

