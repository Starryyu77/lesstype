import AppKit

@MainActor
final class DictionaryLearningPresenter {
    static let shared = DictionaryLearningPresenter()

    func confirm(suggestion: DictionaryLearningSuggestion, appName: String) -> Bool {
        let alert = NSAlert()
        alert.messageText = "加入个人词典？"
        alert.informativeText = """
        检测到你可能把“\(suggestion.spoken)”改成了“\(suggestion.written)”。

        当前 App：\(appName)
        确认后，本地词典会记住这个写法。不会上传到远程服务。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "加入词典")
        alert.addButton(withTitle: "取消")
        NSApplication.shared.activate(ignoringOtherApps: true)
        return alert.runModal() == .alertFirstButtonReturn
    }
}
