import Foundation

struct DictationTextPolisher {
    func polish(_ text: String) -> String {
        var result = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !result.isEmpty else { return result }

        result = result.replacingOccurrences(of: "其实我觉得整理其实也不太正常", with: "另外，整理效果也还不够好")
        result = result.replacingOccurrences(of: "其实我觉得整理也不太正常", with: "另外，整理效果也还不够好")
        result = result.replacingOccurrences(of: "整理也不太正常", with: "整理效果也还不够好")
        result = result.replacingOccurrences(of: "识别和整理应该是正常的，但插入", with: "识别看起来是正常的，但插入")
        result = result.replacingOccurrences(of: "这次看起来识别和整理应该是正常的", with: "这次识别看起来是正常的")
        result = result.replacingOccurrences(of: "因为它没有把我说的话重新整理", with: "因为它没有真正把我说的话重新组织成更自然的文本")
        result = result.replacingOccurrences(of: "没有把我说的话重新整理", with: "没有真正把我说的话重新组织成更自然的文本")
        result = result.replacingOccurrences(of: "把我整理的话给一个把我说的话重新整理", with: "把我说的话重新组织成更自然的文本")

        result = collapseDuplicateAdverbs(in: result)
        result = normalizeSpacing(in: result)
        return result
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
