import Foundation

struct DictationTextPolisher {
    func polish(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        result = removeASRTailArtifacts(in: result)
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

    private func removeASRTailArtifacts(in text: String) -> String {
        var result = text
        let patterns = [
            #"(?:(?:有)?一个(?:什么)?|什么)?\s*要\s*求\s*后\s*续\s*(?:变\s*更\s*正|变\s*更|更\s*正|更\s*改|修\s*改)(?:\s*的?\s*(?:这个|那个)?\s*词)?"#,
            #"(?:(?:有)?一個(?:什麼)?|什麼)?\s*要\s*求\s*後\s*續\s*(?:變\s*更\s*正|變\s*更|更\s*正|更\s*改|修\s*改)(?:\s*的?\s*(?:這個|那個)?\s*詞)?"#,
            #"要求后续(?:变更正|变更|更正|更改|修改)"#,
            #"要求後續(?:變更正|變更|更正|更改|修改)"#
        ]
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        return result
            .replacingOccurrences(of: "会会", with: "会")
            .replacingOccurrences(of: "有一个会出现", with: "会出现")
            .replacingOccurrences(of: "一个会出现", with: "会出现")
            .replacingOccurrences(of: "有一个出现", with: "出现")
            .replacingOccurrences(of: "有一个什么出现", with: "出现")
            .replacingOccurrences(of: "什么出现", with: "出现")
            .replacingOccurrences(of: "这个词出现", with: "出现")
            .replacingOccurrences(of: "那个词出现", with: "出现")
            .trimmingCharacters(in: CharacterSet.whitespacesAndNewlines.union(CharacterSet(charactersIn: "，,。.!！?？；;：:")))
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
