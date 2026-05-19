import Foundation

struct WhisperBenchmarkResult: Equatable {
    let modelPath: String
    let durationMs: Int
    let transcriptLength: Int
}

final class WhisperBenchmark {
    private let provider: ASRProvider

    init(provider: ASRProvider = WhisperCliService()) {
        self.provider = provider
    }

    func run(audioURL: URL, options: ASROptions) async throws -> WhisperBenchmarkResult {
        let result = try await provider.transcribe(audioURL: audioURL, options: options)
        return WhisperBenchmarkResult(
            modelPath: options.modelPath,
            durationMs: result.durationMs,
            transcriptLength: result.text.count
        )
    }
}

