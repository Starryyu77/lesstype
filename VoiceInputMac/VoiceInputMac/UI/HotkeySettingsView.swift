import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            TextField("普通听写快捷键", text: binding(\.dictationHotkey))
            TextField("编辑选中文本快捷键", text: binding(\.editSelectionHotkey))
            Picker("录音模式", selection: binding(\.hotkeyMode)) {
                ForEach(HotkeyMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            Text("推荐使用 Ctrl+Option+A。Fn 键在部分 macOS 键盘设置下不会作为普通 modifier 传给应用；如果 Fn+A 没反应，请改用更稳的备用热键。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("最近捕获按键")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.lastHotkeyEvent)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            HStack {
                Button("使用 Fn+A") {
                    appState.useFnHotkeys()
                }
                Button("使用更稳的 Ctrl+Option+A") {
                    appState.useReliableFallbackHotkeys()
                }
            }

            Button("保存快捷键设置") {
                appState.saveConfig()
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
