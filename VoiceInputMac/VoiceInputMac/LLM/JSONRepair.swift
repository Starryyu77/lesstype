import Foundation

enum JSONRepair {
    static func parseAction(from text: String) -> LLMAction? {
        guard let data = extractJSONObject(from: text).data(using: .utf8) else { return nil }
        if let action = try? JSONDecoder().decode(LLMAction.self, from: data) {
            return normalize(action)
        }
        guard let partial = try? JSONDecoder().decode(PartialLLMAction.self, from: data) else {
            return nil
        }
        return partial.toAction()
    }

    static func parseCommandRoute(from text: String) -> CommandRoute? {
        guard let data = extractJSONObject(from: text).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(CommandRoute.self, from: data)
    }

    static func extractJSONObject(from text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.first == "{", trimmed.last == "}" {
            return trimmed
        }

        var depth = 0
        var startIndex: String.Index?
        var inString = false
        var escaped = false

        for index in trimmed.indices {
            let char = trimmed[index]
            if escaped {
                escaped = false
                continue
            }
            if char == "\\" {
                escaped = true
                continue
            }
            if char == "\"" {
                inString.toggle()
                continue
            }
            guard !inString else { continue }
            if char == "{" {
                if depth == 0 {
                    startIndex = index
                }
                depth += 1
            } else if char == "}" {
                depth -= 1
                if depth == 0, let startIndex {
                    return String(trimmed[startIndex...index])
                }
            }
        }
        return trimmed
    }

    private static func normalize(_ action: LLMAction) -> LLMAction {
        let normalized = normalizeAction(action.action)
        var warnings = action.warnings
        if normalized != action.action {
            warnings.append("invalid_action_normalized")
        }
        return LLMAction(
            action: normalized,
            text: action.text,
            detected_language: normalizeLanguage(action.detected_language),
            format: normalizeFormat(action.format),
            confidence: clamp(action.confidence),
            warnings: warnings
        )
    }

    private static func normalizeAction(_ action: String?) -> String {
        let value = action?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch value {
        case "insert", "replace_selection", "show_panel", "noop":
            return value
        case "":
            return "insert"
        default:
            return "show_panel"
        }
    }

    private static func normalizeLanguage(_ language: String?) -> String {
        let value = language?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch value {
        case "zh", "en", "mixed", "unknown":
            return value
        default:
            return "unknown"
        }
    }

    private static func normalizeFormat(_ format: String?) -> String {
        let value = format?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        switch value {
        case "plain", "markdown", "email", "message", "code_comment":
            return value
        default:
            return "plain"
        }
    }

    private static func defaultConfidence(for action: String) -> Double {
        switch action {
        case "noop":
            return 1.0
        case "show_panel":
            return 0.4
        default:
            return 0.75
        }
    }

    private static func clamp(_ value: Double) -> Double {
        min(max(value, 0), 1)
    }

    private struct PartialLLMAction: Decodable {
        let action: String?
        let text: String?
        let detected_language: String?
        let format: String?
        let confidence: Double?
        let warnings: [String]?

        func toAction() -> LLMAction? {
            let normalizedAction = JSONRepair.normalizeAction(action)
            let normalizedText = (text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
            guard normalizedAction == "noop" || !normalizedText.isEmpty else {
                return nil
            }

            var normalizedWarnings = warnings ?? []
            if let action, normalizedAction != action {
                normalizedWarnings.append("invalid_action_normalized")
            }

            return LLMAction(
                action: normalizedAction,
                text: normalizedText,
                detected_language: JSONRepair.normalizeLanguage(detected_language),
                format: JSONRepair.normalizeFormat(format),
                confidence: JSONRepair.clamp(confidence ?? JSONRepair.defaultConfidence(for: normalizedAction)),
                warnings: normalizedWarnings
            )
        }
    }
}
