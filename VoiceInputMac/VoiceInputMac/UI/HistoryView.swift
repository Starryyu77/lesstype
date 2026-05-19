import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        SettingsPage(
            title: "历史",
            subtitle: "本地保存的 ASR、润色结果和目标 App 信息。",
            systemImage: "clock"
        ) {
            SettingsPanel("查找") {
                HStack(spacing: 10) {
                    TextField("搜索历史", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        appState.historyItems = (try? appState.historyStore.search(searchText)) ?? []
                    } label: {
                        Label("搜索", systemImage: "magnifyingglass")
                    }
                    Button {
                        appState.refreshHistory()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                    Button(role: .destructive) {
                        appState.clearHistory()
                    } label: {
                        Label("清空", systemImage: "trash")
                    }
                }
            }

            SettingsPanel("最近记录") {
                if appState.historyItems.isEmpty {
                    SettingsEmptyState(title: "暂无历史", detail: "完成一次语音输入后，本地历史会显示在这里。", systemImage: "clock")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.historyItems) { item in
                            HistoryItemRow(item: item, appState: appState)
                        }
                    }
                }
            }
        }
        .onAppear { appState.refreshHistory() }
    }
}

private struct HistoryItemRow: View {
    let item: HistoryItem
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                SettingsStatusLabel(
                    text: item.activeApp.isEmpty ? "Unknown" : item.activeApp,
                    systemImage: "app",
                    tone: .neutral
                )
                Text(item.createdAt)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(item.finalText, forType: .string)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                Button(role: .destructive) {
                    try? appState.historyStore.delete(id: item.id)
                    appState.refreshHistory()
                } label: {
                    Label("删除", systemImage: "trash")
                }
                .buttonStyle(.borderless)
            }
            Text(item.finalText)
                .font(.body)
                .lineLimit(3)
                .textSelection(.enabled)
            Text(item.rawASRText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
