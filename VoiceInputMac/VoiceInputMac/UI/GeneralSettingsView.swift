import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Picker("默认风格", selection: binding(\.defaultStyleProfile)) {
                Text("Auto").tag("auto")
                ForEach(appState.styleProfiles) { profile in
                    Text(profile.name).tag(profile.name)
                }
            }
            Toggle("保存历史", isOn: binding(\.saveHistory))
            Toggle("保存音频", isOn: binding(\.saveAudio))
            Toggle("粘贴后恢复剪贴板", isOn: binding(\.restoreClipboardAfterPaste))
            TextField("日志级别", text: binding(\.logLevel))

            Section("词典学习") {
                Button {
                    appState.learnLastCorrection()
                } label: {
                    Label("学习刚才修改", systemImage: "text.badge.checkmark")
                }

                Text(appState.learningMessage.isEmpty ? "语音输入后，手动修正一个短词，再点这里确认加入个人词典。" : appState.learningMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("保存设置") {
                    appState.saveConfig()
                }
                Button("清空历史", role: .destructive) {
                    appState.clearHistory()
                }
                Button("打开本地数据目录") {
                    NSWorkspace.shared.open(appState.database.url.deletingLastPathComponent())
                }
            }
        }
        .padding()
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppConfig, Value>) -> Binding<Value> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: {
                appState.config[keyPath: keyPath] = $0
                appState.saveConfig()
            }
        )
    }
}
