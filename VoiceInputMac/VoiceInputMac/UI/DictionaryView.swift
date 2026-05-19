import SwiftUI

struct DictionaryView: View {
    @ObservedObject var appState: AppState
    @State private var editingID: Int?
    @State private var spoken = ""
    @State private var written = ""
    @State private var aliases = ""
    @State private var scope = "global"
    @State private var priority = 5
    @State private var searchText = ""

    private var filteredEntries: [DictionaryEntry] {
        guard !searchText.isEmpty else { return appState.dictionaryEntries }
        return appState.dictionaryEntries.filter {
            $0.spoken.localizedCaseInsensitiveContains(searchText) ||
                $0.written.localizedCaseInsensitiveContains(searchText) ||
                $0.aliasesText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        SettingsPage(
            title: "个人词典",
            subtitle: "用于 ASR 后处理和 LLM prompt，保证专有名词写法稳定。",
            systemImage: "book"
        ) {
            SettingsPanel("词条") {
                HStack(spacing: 10) {
                    TextField("搜索 spoken / written / aliases", text: $searchText)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        appState.loadLocalState()
                    } label: {
                        Label("刷新", systemImage: "arrow.clockwise")
                    }
                }

                if filteredEntries.isEmpty {
                    SettingsEmptyState(title: "没有词条", detail: "添加术语后，听写会优先使用 written 形式。", systemImage: "book")
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredEntries) { entry in
                            DictionaryEntryRow(entry: entry, load: load, delete: delete)
                        }
                    }
                }
            }

            SettingsPanel(editingID == nil ? "添加词条" : "编辑词条") {
                SettingsRow("Spoken", detail: "用户可能说出的形式。") {
                    TextField("cursor", text: $spoken)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                SettingsRow("Written", detail: "最终应写入文本的形式。") {
                    TextField("Cursor", text: $written)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                SettingsRow("Aliases", detail: "逗号分隔，例如 type less, swiftui。") {
                    TextField("aliases", text: $aliases)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                SettingsRow("Scope") {
                    TextField("global", text: $scope)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                SettingsRow("Priority") {
                    Stepper("\(priority)", value: $priority, in: 0...100)
                }

                HStack(spacing: 10) {
                    Button(editingID == nil ? "添加词条" : "保存修改") {
                        save()
                    }
                    .disabled(spoken.isEmpty || written.isEmpty)
                    Button("清空表单") {
                        resetForm()
                    }
                    Spacer()
                }
            }
        }
    }

    private func load(_ entry: DictionaryEntry) {
        editingID = entry.id
        spoken = entry.spoken
        written = entry.written
        aliases = entry.aliasesText
        scope = entry.scope
        priority = entry.priority
    }

    private func delete(_ entry: DictionaryEntry) {
        if let id = entry.id {
            try? appState.dictionaryStore.delete(id: id)
            appState.loadLocalState()
        }
    }

    private func save() {
        let entry = DictionaryEntry(
            id: editingID,
            spoken: spoken,
            written: written,
            aliases: aliases.split(separator: ",").map { $0.trimmingCharacters(in: .whitespacesAndNewlines) },
            scope: scope,
            priority: priority
        )
        if editingID == nil {
            try? appState.dictionaryStore.insert(entry)
        } else {
            try? appState.dictionaryStore.update(entry)
        }
        resetForm()
        appState.loadLocalState()
    }

    private func resetForm() {
        editingID = nil
        spoken = ""
        written = ""
        aliases = ""
        scope = "global"
        priority = 5
    }
}

private struct DictionaryEntryRow: View {
    let entry: DictionaryEntry
    let load: (DictionaryEntry) -> Void
    let delete: (DictionaryEntry) -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(entry.spoken)
                        .font(.system(.body, design: .monospaced))
                    Image(systemName: "arrow.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(entry.written)
                        .font(.headline)
                }
                if !entry.aliases.isEmpty {
                    Text(entry.aliasesText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
            SettingsStatusLabel(text: "P\(entry.priority)", systemImage: "number", tone: .neutral)
            Button {
                load(entry)
            } label: {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)
            Button(role: .destructive) {
                delete(entry)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
