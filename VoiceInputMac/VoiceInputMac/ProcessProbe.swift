import Foundation

enum ProcessProbe {
    static func commandExists(_ command: String) async -> Bool {
        let trimmed = command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        if trimmed.contains("/"), FileManager.default.isExecutableFile(atPath: trimmed) {
            return true
        }

        return await withCheckedContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = ["which", trimmed]
            process.standardOutput = Pipe()
            process.standardError = Pipe()
            process.terminationHandler = { process in
                continuation.resume(returning: process.terminationStatus == 0)
            }
            do {
                try process.run()
            } catch {
                continuation.resume(returning: false)
            }
        }
    }
}

