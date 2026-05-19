import Foundation

final class WhisperService: ASRProvider {
    private let cliFallback = WhisperCliService()
    private(set) var isModelLoaded = false

    func preloadModel(at path: String) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw AppError.asrModelMissing
        }
        isModelLoaded = true
    }

    func transcribe(audioURL: URL, options: ASROptions) async throws -> ASRResult {
        try await cliFallback.transcribe(audioURL: audioURL, options: options)
    }
}

