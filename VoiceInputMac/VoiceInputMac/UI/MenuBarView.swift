import AppKit
import SwiftUI

struct MenuBarView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(appState.phase.menuTitle, systemImage: appState.phase.symbolName)
                .font(.headline)

            Text(appState.message)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)

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

            Button {
                appState.learnLastCorrection()
            } label: {
                Label("学习刚才修改", systemImage: appState.canLearnLastCorrection ? "text.badge.checkmark" : "text.badge.plus")
            }

            if !appState.learningMessage.isEmpty {
                Text(appState.learningMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
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
        .padding(.vertical, 8)
        .frame(width: 260)
    }

    private func openSettingsWindow() {
        SettingsWindowPresenter.shared.show(appState: appState)
    }
}
