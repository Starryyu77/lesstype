import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: appState.phase.symbolName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(appState.phase == .error ? .red : .accentColor)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 7)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                VStack(alignment: .leading, spacing: 2) {
                    Text("Lesstype")
                        .font(.headline)
                    Text(appState.message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }

            Divider()

            Button {
                appState.runManualDictation()
            } label: {
                Label("开始语音输入", systemImage: "mic.fill")
            }

            Button {
                appState.runManualEditSelection()
            } label: {
                Label("编辑选中文本", systemImage: "text.cursor")
            }

            Divider()

            Button {
                openSettingsWindow()
            } label: {
                Label("打开设置", systemImage: "gearshape")
            }

            Button {
                openSettingsWindow()
            } label: {
                Label("打开历史", systemImage: "clock")
            }

            Button {
                openSettingsWindow()
            } label: {
                Label("打开词典", systemImage: "book")
            }

            Button {
                openSettingsWindow()
            } label: {
                Label("检查权限", systemImage: "lock.shield")
            }

            Divider()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Label("退出", systemImage: "power")
            }
        }
        .padding(12)
        .frame(width: 286)
    }

    private func openSettingsWindow() {
        SettingsWindowPresenter.shared.show(appState: appState)
    }
}
