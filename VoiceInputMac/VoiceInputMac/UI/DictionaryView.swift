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

    var filteredEntries: [DictionaryEntry] {
        guard !searchText.isEmpty else { return appState.dictionaryEntries }
        return appState.dictionaryEntries.filter {
            $0.spoken.localizedCaseInsensitiveContains(searchText) ||
                $0.written.localizedCaseInsensitiveContains(searchText) ||
                $0.aliasesText.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                TextField("搜索词条", text: $searchText)
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
