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
    @State private var showLearnedOnly = false

    var filteredEntries: [DictionaryEntry] {
        let scoped = showLearnedOnly ? appState.dictionaryEntries.filter(\.isLearned) : appState.dictionaryEntries
        guard !searchText.isEmpty else { return scoped }
        return scoped.filter {
            $0.spoken.localizedCaseInsensitiveContains(searchText) ||
                $0.written.localizedCaseInsensitiveContains(searchText) ||
                $0.aliasesText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("词典学习")
                        .font(.headline)
                    Text(appState.learningMessage.isEmpty ? "修改刚才插入的短词后，点这里把纠错写入本地个人词典。" : appState.learningMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    appState.learnLastCorrection()
                } label: {
                    Label("学习刚才修改", systemImage: "text.badge.checkmark")
                }
            }

            Divider()

            HStack {
                TextField("搜索词条", text: $searchText)
                Toggle("只看学习词条", isOn: $showLearnedOnly)
                    .toggleStyle(.checkbox)
                Button("刷新") { appState.loadLocalState() }
            }

            List(filteredEntries) { entry in
                HStack {
                    VStack(alignment: .leading) {
                        Text("\(entry.spoken) -> \(entry.written)")
                        if !entry.aliases.isEmpty {
                            Text(entry.aliasesText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if entry.isLearned {
                        Text("learned")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.accentColor.opacity(0.12))
                            .foregroundStyle(Color.accentColor)
                            .clipShape(RoundedRectangle(cornerRadius: 5))
                    }
                    Spacer()
                    Text("P\(entry.priority)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button {
                        load(entry)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    Button(role: .destructive) {
                        if let id = entry.id {
                            try? appState.dictionaryStore.delete(id: id)
                            appState.loadLocalState()
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Spoken")
                    TextField("cursor", text: $spoken)
                }
                GridRow {
                    Text("Written")
                    TextField("Cursor", text: $written)
                }
                GridRow {
                    Text("Aliases")
                    TextField("逗号分隔", text: $aliases)
                }
                GridRow {
                    Text("Scope")
                    TextField("global", text: $scope)
                }
                GridRow {
                    Text("Priority")
                    Stepper("\(priority)", value: $priority, in: 0...100)
                }
            }

            HStack {
                Button(editingID == nil ? "添加词条" : "保存修改") {
                    save()
                }
                .disabled(spoken.isEmpty || written.isEmpty)

                Button("清空表单") {
                    resetForm()
                }
            }
        }
        .padding()
    }

    private func load(_ entry: DictionaryEntry) {
        editingID = entry.id
        spoken = entry.spoken
        written = entry.written
        aliases = entry.aliasesText
        scope = entry.scope
        priority = entry.priority
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
