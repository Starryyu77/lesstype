import Foundation

struct WhisperModelManager {
    static let supportedModels = ["large-v3-turbo", "large-v3", "medium", "small"]

    func validateModelPath(_ path: String) -> Bool {
        !path.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            FileManager.default.fileExists(atPath: path)
    }

    func displayName(for model: String) -> String {
        model
    }
}

