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
            Text("当前 MVP 内置监听 Option+Space 与 Option+Shift+Space。可编辑快捷键配置已持久化，真正的动态重绑定留到阶段 2。")
                .font(.caption)
                .foregroundStyle(.secondary)
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

