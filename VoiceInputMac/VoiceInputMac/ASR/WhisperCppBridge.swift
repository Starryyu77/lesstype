import Foundation

final class WhisperCppBridge {
    enum BridgeState: Equatable {
        case notLinked
        case ready
    }

    private(set) var state: BridgeState = .notLinked

    func loadModel(at path: String, useMetal: Bool, useCoreML: Bool) throws {
        guard FileManager.default.fileExists(atPath: path) else {
            throw AppError.asrModelMissing
        }
        state = .notLinked
        throw AppError.asrFailed("whisper.cpp C API bridge is reserved for phase 2")
    }
}

