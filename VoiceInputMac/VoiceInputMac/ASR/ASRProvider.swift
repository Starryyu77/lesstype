import Foundation

protocol ASRProvider {
    func transcribe(audioURL: URL, options: ASROptions) async throws -> ASRResult
}

struct ASROptions {
    let language: String
    let useMetal: Bool
    let useCoreML: Bool
    let maxSegmentSeconds: Int
    let modelPath: String
    let cliCommand: String
}

struct ASRResult: Equatable {
    let text: String
    let language: String?
    let durationMs: Int
    let segments: [ASRSegment]
}

struct ASRSegment: Equatable {
    let start: Double
    let end: Double
    let text: String
}

