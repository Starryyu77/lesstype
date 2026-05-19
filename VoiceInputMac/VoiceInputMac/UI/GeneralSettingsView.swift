import AppKit
import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        SettingsPage(
            title: "通用",
            subtitle: "控制本地数据、默认风格和隐私相关行为。",
            systemImage: "gearshape"
        ) {
            SettingsPanel("默认行为", subtitle: "这些设置会立即保存到本机 SQLite。") {
                SettingsRow("默认风格", detail: "Auto 会根据前台 App 匹配聊天、邮件、笔记或代码场景。") {
                    Picker("", selection: binding(\.defaultStyleProfile)) {
                        Text("Auto").tag("auto")
                        ForEach(appState.styleProfiles) { profile in
                            Text(profile.name).tag(profile.name)
                        }
                    }
                    .labelsHidden()
                }
                SettingsDivider()
                SettingsRow("日志级别", detail: "用于本地诊断，不会上传遥测。") {
                    TextField("info", text: binding(\.logLevel))
                        .textFieldStyle(.roundedBorder)
                }
            }

            SettingsPanel("隐私与历史", subtitle: "音频默认不会保存，历史只留在本机。") {
                SettingsRow("保存历史", detail: "记录原始 ASR、最终文本、目标 App 和耗时。") {
                    Toggle("", isOn: binding(\.saveHistory))
                        .labelsHidden()
                }
                SettingsDivider()
                SettingsRow("保存音频", detail: "默认关闭。开启后才会保留录音文件。") {
                    Toggle("", isOn: binding(\.saveAudio))
                        .labelsHidden()
                }
                SettingsDivider()
                SettingsRow("恢复剪贴板", detail: "剪贴板 fallback 粘贴后尽量还原原内容。") {
                    Toggle("", isOn: binding(\.restoreClipboardAfterPaste))
                        .labelsHidden()
                }
            }

            SettingsPanel("本地数据") {
                HStack(spacing: 10) {
                    Button {
                        NSWorkspace.shared.open(appState.database.url.deletingLastPathComponent())
                    } label: {
                        Label("打开数据目录", systemImage: "folder")
                    }
                    Button(role: .destructive) {
                        appState.clearHistory()
                    } label: {
                        Label("清空历史", systemImage: "trash")
                    }
                    Spacer()
                    SettingsStatusLabel(text: "Local only", systemImage: "lock", tone: .success)
                }
            }
        }
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
