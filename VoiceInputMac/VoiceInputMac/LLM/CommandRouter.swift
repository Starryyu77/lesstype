import Foundation

enum RoutedCommandType: String, Equatable {
    case dictation
    case editSelection
    case systemCommand
    case unknown
}

struct RoutedCommand: Equatable {
    let type: RoutedCommandType
    let command: String
    let confidence: Double
}

struct CommandRouter {
    private let editKeywords = [
        "改短", "短一点", "更正式", "正式一点", "更口语", "润色",
        "翻译成英文", "翻译成中文", "列成要点", "总结"
    ]
    private let cancelKeywords = ["取消", "算了", "不要了", "重新来"]
    private let deleteLastKeywords = ["删除刚才", "删掉刚才", "撤销刚才"]

    func route(rawTranscript: String, hasSelectedText: Bool) -> RoutedCommand {
        let text = rawTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else {
            return RoutedCommand(type: .unknown, command: "", confidence: 0)
        }

        if let keyword = (cancelKeywords + deleteLastKeywords).first(where: { text.contains($0) }) {
            return RoutedCommand(type: .systemCommand, command: keyword, confidence: 0.95)
        }

        if hasSelectedText, let keyword = editKeywords.first(where: { text.contains($0) }) {
            return RoutedCommand(type: .editSelection, command: keyword, confidence: 0.9)
        }

        if !hasSelectedText {
            return RoutedCommand(type: .dictation, command: "dictation", confidence: 0.75)
        }

        return RoutedCommand(type: .dictation, command: "dictation", confidence: 0.6)
    }
}

