import Foundation

enum JSONRepair {
    static func parseAction(from text: String) -> LLMAction? {
        guard let data = extractJSONObject(from: text).data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LLMAction.self, from: data)
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
}

