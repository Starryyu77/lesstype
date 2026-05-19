import Foundation

final class WhisperCliService: ASRProvider {
    func transcribe(audioURL: URL, options: ASROptions) async throws -> ASRResult {
        guard FileManager.default.fileExists(atPath: audioURL.path) else {
            throw AppError.asrFailed("Audio file does not exist")
        }
        let attributes = try FileManager.default.attributesOfItem(atPath: audioURL.path)
        let size = (attributes[.size] as? NSNumber)?.intValue ?? 0
        guard size > 44 else {
            throw AppError.asrFailed("Audio file is empty")
        }
        guard !options.modelPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              FileManager.default.fileExists(atPath: options.modelPath) else {
            throw AppError.asrModelMissing
        }

        let start = Date()
        let output = try await runWhisper(audioURL: audioURL, options: options)
        let text = Self.clean(stdout: output).trimmingCharacters(in: .whitespacesAndNewlines)
        return ASRResult(
            text: text,
            language: options.language == "auto" ? nil : options.language,
            durationMs: Int(Date().timeIntervalSince(start) * 1000),
            segments: text.isEmpty ? [] : [ASRSegment(start: 0, end: 0, text: text)]
        )
    }

    private func runWhisper(audioURL: URL, options: ASROptions) async throws -> String {
        try await withThrowingTaskGroup(of: String.self) { group in
            group.addTask {
                try await self.launchProcess(audioURL: audioURL, options: options)
            }
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(max(options.maxSegmentSeconds * 4, 60)) * 1_000_000_000)
                throw AppError.asrTimeout
            }
            guard let value = try await group.next() else {
                throw AppError.asrFailed("whisper-cli returned no output")
            }
            group.cancelAll()
            return value
        }
    }

    private func launchProcess(audioURL: URL, options: ASROptions) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            let outputBaseURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("voiceinput-whisper-\(UUID().uuidString)")
            var arguments = [
                options.cliCommand,
                "-m", options.modelPath,
                "-f", audioURL.path,
                "-l", options.language,
                "-nt",
                "-otxt",
                "-of", outputBaseURL.path,
                "-np"
            ]
            if options.useMetal {
                arguments.append(contentsOf: ["--flash-attn"])
            }
            process.arguments = arguments

            let stdout = Pipe()
            let stderr = Pipe()
            process.standardOutput = stdout
            process.standardError = stderr

            process.terminationHandler = { process in
                let outData = stdout.fileHandleForReading.readDataToEndOfFile()
                let errData = stderr.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errData, encoding: .utf8) ?? ""
                let transcriptURL = outputBaseURL.appendingPathExtension("txt")
                let transcript = (try? String(contentsOf: transcriptURL, encoding: .utf8)) ?? ""
                try? FileManager.default.removeItem(at: transcriptURL)

                if process.terminationStatus == 0 {
                    continuation.resume(returning: transcript.isEmpty ? output : transcript)
                } else {
                    let sanitized = errorOutput.replacingOccurrences(of: "Authorization: Bearer [^\\n]+", with: "Authorization: Bearer <redacted>", options: .regularExpression)
                    continuation.resume(throwing: AppError.asrFailed(sanitized.isEmpty ? "whisper-cli exited with \(process.terminationStatus)" : sanitized))
                }
            }

            do {
                try process.run()
            } catch {
                continuation.resume(throwing: AppError.asrFailed(error.localizedDescription))
            }
        }
    }

    static func clean(stdout: String) -> String {
        let lines = stdout
            .split(separator: "\n")
            .map(String.init)
            .filter { line in
                let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
                return !trimmed.isEmpty && !isDiagnosticLine(trimmed)
            }
        let joined = lines.joined(separator: " ")
        return joined
            .replacingOccurrences(of: #"\[[^\]]+\]"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isDiagnosticLine(_ line: String) -> Bool {
        let prefixes = [
            "load_backend:",
            "ggml_",
            "whisper_",
            "system_info",
            "main:",
            "objc[",
            "dyld["
        ]
        if prefixes.contains(where: { line.hasPrefix($0) }) {
            return true
        }
        let diagnosticFragments = [
            " load time",
            " sample time",
            " encode time",
            " decode time",
            " total time",
            "recommendedMaxWorkingSetSize",
            "MTL backend",
            "BLAS backend",
            "CPU backend"
        ]
        return diagnosticFragments.contains(where: line.contains)
    }
}
