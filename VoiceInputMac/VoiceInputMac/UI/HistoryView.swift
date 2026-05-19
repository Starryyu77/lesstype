import SwiftUI

struct HistoryView: View {
    @ObservedObject var appState: AppState
    @State private var searchText = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("搜索历史", text: $searchText)
                Button("搜索") {
                    appState.historyItems = (try? appState.historyStore.search(searchText)) ?? []
                }
                Button("刷新") {
                    appState.refreshHistory()
                }
                Button("清空", role: .destructive) {
                    appState.clearHistory()
                }
            }

            List(appState.historyItems) { item in
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(item.activeApp.isEmpty ? "Unknown" : item.activeApp)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(item.createdAt)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.finalText)
                        .lineLimit(3)
                    Text(item.rawASRText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack {
                        Button("复制结果") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(item.finalText, forType: .string)
                        }
                        Button("删除", role: .destructive) {
                            try? appState.historyStore.delete(id: item.id)
                            appState.refreshHistory()
                        }
                    }
                    .font(.caption)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .onAppear { appState.refreshHistory() }
    }
}

