import Foundation

struct BuiltPrompt: Equatable {
    let system: String
    let user: String
}

final class PromptBuilder {
    func build(
        mode: PipelineMode,
        activeApp: String,
        windowTitle: String,
        selectedText: String,
        contextBefore: String,
        personalDictionary: [DictionaryEntry],
        styleProfile: StyleProfile?,
        rawTranscript: String
    ) throws -> BuiltPrompt {
        let name = mode == .editSelection ? "edit_selection.zh" : "polish.zh"
        let template = try loadPrompt(named: name)
        return fill(
            template: template,
            values: [
                "active_app": activeApp,
                "window_title": windowTitle,
                "mode": mode.rawValue,
                "selected_text": selectedText,
                "context_before": contextBefore,
                "personal_dictionary": personalDictionary.map(\.promptLine).joined(separator: "\n"),
                "style_profile": styleProfile?.prompt_suffix ?? "",
                "raw_transcript": rawTranscript
            ]
        )
    }

    func buildCommandRouter(hasSelectedText: Bool, rawTranscript: String) throws -> BuiltPrompt {
        let template = try loadPrompt(named: "command_router.zh")
        return fill(
            template: template,
            values: [
                "has_selected_text": hasSelectedText ? "true" : "false",
                "raw_transcript": rawTranscript
            ]
        )
    }

    private func loadPrompt(named name: String) throws -> String {
        for url in promptCandidates(named: name) {
            if FileManager.default.fileExists(atPath: url.path) {
                return try String(contentsOf: url, encoding: .utf8)
            }
        }

        throw AppError.llmFailed("Prompt file \(name).md not found")
    }

    private func promptCandidates(named name: String) -> [URL] {
        var urls: [URL] = []
        let bundleName = "VoiceInputMac_VoiceInputMac.bundle"

        if let resourceURL = Bundle.main.resourceURL {
            urls.append(resourceURL.appendingPathComponent(bundleName).appendingPathComponent("\(name).md"))
            urls.append(resourceURL.appendingPathComponent("Prompts").appendingPathComponent("\(name).md"))
        }

        if let executableURL = Bundle.main.executableURL {
            urls.append(executableURL.deletingLastPathComponent().appendingPathComponent(bundleName).appendingPathComponent("\(name).md"))
        }

        urls.append(
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("VoiceInputMac/Prompts/\(name).md")
        )
        urls.append(
            URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
                .appendingPathComponent("VoiceInputMac/VoiceInputMac/Prompts/\(name).md")
        )
        return urls
    }

    private func fill(template: String, values: [String: String]) -> BuiltPrompt {
        var rendered = template
        for (key, value) in values {
            rendered = rendered.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        let parts = splitSystemUser(rendered)
        return BuiltPrompt(system: parts.system, user: parts.user)
    }

    private func splitSystemUser(_ rendered: String) -> (system: String, user: String) {
        guard let systemRange = rendered.range(of: "SYSTEM:"),
              let userRange = rendered.range(of: "USER:") else {
            return (rendered, "")
        }
        let system = rendered[systemRange.upperBound..<userRange.lowerBound]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let user = rendered[userRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return (system, user)
    }
}
