import SwiftUI

struct StyleProfilesView: View {
    @ObservedObject var appState: AppState
    @State private var editingID: Int?
    @State private var name = ""
    @State private var appPattern = ""
    @State private var promptSuffix = ""
    @State private var examples = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            List(appState.styleProfiles) { profile in
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(profile.name)
                            .font(.headline)
                        Text(profile.app_pattern)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text(profile.prompt_suffix)
                            .font(.body)
                    }
                    Spacer()
                    Button {
                        load(profile)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .buttonStyle(.borderless)
                    Button(role: .destructive) {
                        if let id = profile.id {
                            try? appState.styleProfileStore.delete(id: id)
                            appState.loadLocalState()
                            if editingID == id {
                                resetForm()
                            }
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.vertical, 6)
            }

            Divider()

            Grid(alignment: .leading, horizontalSpacing: 12, verticalSpacing: 8) {
                GridRow {
                    Text("Name")
                    TextField("chat", text: $name)
                }
                GridRow {
                    Text("App Pattern")
                    TextField("WeChat|Telegram", text: $appPattern)
                }
                GridRow {
                    Text("Prompt Suffix")
                    TextField("风格说明", text: $promptSuffix, axis: .vertical)
                        .lineLimit(3...6)
                }
                GridRow {
                    Text("Examples")
                    TextField("可选示例", text: $examples, axis: .vertical)
                        .lineLimit(2...4)
                }
            }

            HStack {
                Button(editingID == nil ? "添加 Profile" : "保存修改") {
                    save()
                }
                .disabled(name.isEmpty)
                Button("清空表单") {
                    resetForm()
                }
            }
        }
        .padding()
    }

    private func load(_ profile: StyleProfile) {
        editingID = profile.id
        name = profile.name
        appPattern = profile.app_pattern
        promptSuffix = profile.prompt_suffix
        examples = profile.examples
    }

    private func save() {
        let profile = StyleProfile(
            id: editingID,
            name: name,
            app_pattern: appPattern,
            prompt_suffix: promptSuffix,
            examples: examples
        )
        if editingID == nil {
            try? appState.styleProfileStore.insert(profile)
        } else {
            try? appState.styleProfileStore.update(profile)
        }
        resetForm()
        appState.loadLocalState()
    }

    private func resetForm() {
        editingID = nil
        name = ""
        appPattern = ""
        promptSuffix = ""
        examples = ""
    }
}
