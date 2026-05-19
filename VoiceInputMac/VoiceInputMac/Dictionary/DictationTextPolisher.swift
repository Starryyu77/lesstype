import Foundation

struct DictationTextPolisher {
    func polish(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        result = result.replacingOccurrences(of: "其实我觉得整理其实也不太正常", with: "整理其实也不太正常")
        result = result.replacingOccurrences(of: "其实我觉得整理也不太正常", with: "整理也不太正常")
        result = removeSupersededPositiveJudgement(
            topic: "整理",
            negativeMarkers: ["整理不太正常", "整理也不太正常", "整理不够正常"],
            from: result
        )
        result = collapseDuplicateAdverbs(in: result)
        result = normalizeSpacing(in: result)
        return result
    }

    private func removeSupersededPositiveJudgement(topic: String, negativeMarkers: [String], from text: String) -> String {
        guard negativeMarkers.contains(where: { text.contains($0) }) else {
            return text
        }

        var result = text
        result = result.replacingOccurrences(of: "识别和整理应该是正常的", with: "识别应该是正常的")
        result = result.replacingOccurrences(of: "识别和整理是正常的", with: "识别是正常的")
        result = result.replacingOccurrences(of: "识别和整理看起来是正常的", with: "识别看起来是正常的")
        result = result.replacingOccurrences(of: "识别和整理应该正常", with: "识别应该正常")
        result = result.replacingOccurrences(of: "看起来识别和整理应该是正常的", with: "看起来识别应该是正常的")

        let escapedTopic = NSRegularExpression.escapedPattern(for: topic)
        let patterns = [
            #"\#(escapedTopic)[^。！？；;，,]*应该是正常的[，,。]?"#,
            #"\#(escapedTopic)[^。！？；;，,]*看起来是正常的[，,。]?"#,
            #"\#(escapedTopic)[^。！？；;，,]*是正常的[，,。]?"#
        ]

        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func collapseDuplicateAdverbs(in text: String) -> String {
        text
            .replacingOccurrences(of: "其实其实", with: "其实")
            .replacingOccurrences(of: "应该应该", with: "应该")
            .replacingOccurrences(of: "正常的正常", with: "正常")
    }

    private func normalizeSpacing(in text: String) -> String {
        text
            .replacingOccurrences(of: "。。", with: "。")
            .replacingOccurrences(of: "，，", with: "，")
            .replacingOccurrences(of: "。，", with: "。")
            .replacingOccurrences(of: "，。", with: "。")
    }
}
