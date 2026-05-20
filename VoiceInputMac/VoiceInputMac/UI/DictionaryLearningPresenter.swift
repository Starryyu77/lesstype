import AppKit

@MainActor
final class DictionaryLearningPresenter {
    static let shared = DictionaryLearningPresenter()

    func confirm(suggestion: DictionaryLearningSuggestion, appName: String) -> DictionaryLearningSuggestion? {
        let alert = NSAlert()
        alert.messageText = "加入个人词典？"
        alert.informativeText = """
        检测到你可能把“\(suggestion.spoken)”改成了“\(suggestion.written)”。

        当前 App：\(appName)
        如果截词不准，可以先编辑下面两个字段，再选择“编辑后再加入”。不会上传到远程服务。
        """
        alert.alertStyle = .informational
        alert.addButton(withTitle: "加入词典")
        alert.addButton(withTitle: "编辑后再加入")
        alert.addButton(withTitle: "取消")
        alert.accessoryView = accessoryView(spoken: suggestion.spoken, written: suggestion.written)
        NSApplication.shared.activate(ignoringOtherApps: true)
        let response = alert.runModal()
        switch response {
        case .alertFirstButtonReturn:
            return suggestion
        case .alertSecondButtonReturn:
            guard let stack = alert.accessoryView as? NSStackView,
                  let spokenField = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.identifier?.rawValue == "spoken" }),
                  let writtenField = stack.arrangedSubviews.compactMap({ $0 as? NSTextField }).first(where: { $0.identifier?.rawValue == "written" }) else {
                return nil
            }
            let edited = DictionaryLearningSuggestion(
                spoken: spokenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines),
                written: writtenField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
            )
            return edited.spoken.isEmpty || edited.written.isEmpty ? nil : edited
        default:
            return nil
        }
    }

    private func accessoryView(spoken: String, written: String) -> NSView {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6

        let spokenLabel = NSTextField(labelWithString: "识别成 / spoken")
        let spokenField = NSTextField(string: spoken)
        spokenField.identifier = NSUserInterfaceItemIdentifier("spoken")
        spokenField.frame.size.width = 360

        let writtenLabel = NSTextField(labelWithString: "改成 / written")
        let writtenField = NSTextField(string: written)
        writtenField.identifier = NSUserInterfaceItemIdentifier("written")
        writtenField.frame.size.width = 360

        for view in [spokenLabel, spokenField, writtenLabel, writtenField] {
            stack.addArrangedSubview(view)
        }
        return stack
    }
}
