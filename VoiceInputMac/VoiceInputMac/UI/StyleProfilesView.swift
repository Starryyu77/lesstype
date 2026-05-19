import SwiftUI

struct StyleProfilesView: View {
    @ObservedObject var appState: AppState
    @State private var editingID: Int?
    @State private var name = ""
    @State private var appPattern = ""
    @State private var promptSuffix = ""
    @State private var examples = ""

    var body: some View {
        SettingsPage(
            title: "场景风格",
            subtitle: "根据当前 App 匹配聊天、邮件、笔记和代码写作风格。",
            systemImage: "paintpalette"
        ) {
            SettingsPanel("Profiles") {
                if appState.styleProfiles.isEmpty {
                    SettingsEmptyState(title: "没有 Profile", detail: "默认 profile 会在本地数据库初始化时创建。", systemImage: "paintpalette")
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(appState.styleProfiles) { profile in
                            StyleProfileRow(profile: profile, load: load, delete: delete)
                        }
                    }
                }
            }

            SettingsPanel(editingID == nil ? "添加 Profile" : "编辑 Profile") {
                SettingsRow("Name") {
                    TextField("chat", text: $name)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                SettingsRow("App Pattern", detail: "正则匹配 App 名称或 bundle identifier。") {
                    TextField("WeChat|Telegram", text: $appPattern)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Prompt Suffix")
                        .font(.body)
                    TextField("风格说明", text: $promptSuffix, axis: .vertical)
                        .lineLimit(3...6)
                        .textFieldStyle(.roundedBorder)
                }
                SettingsDivider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("Examples")
                        .font(.body)
                    TextField("可选示例", text: $examples, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }

                HStack(spacing: 10) {
                    Button(editingID == nil ? "添加 Profile" : "保存修改") {
                        save()
                    }
                    .disabled(name.isEmpty)
                    Button("清空表单") {
                        resetForm()
                    }
                    Spacer()
                }
            }
        }
    }

    private func load(_ profile: StyleProfile) {
        editingID = profile.id
        name = profile.name
        appPattern = profile.app_pattern
        promptSuffix = profile.prompt_suffix
        examples = profile.examples
    }

    private func delete(_ profile: StyleProfile) {
        if let id = profile.id {
            try? appState.styleProfileStore.delete(id: id)
            appState.loadLocalState()
            if editingID == id {
                resetForm()
            }
        }
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

private struct StyleProfileRow: View {
    let profile: StyleProfile
    let load: (StyleProfile) -> Void
    let delete: (StyleProfile) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(profile.name)
                    .font(.headline)
                Spacer()
                Button {
                    load(profile)
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.borderless)
                Button(role: .destructive) {
                    delete(profile)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }
            Text(profile.app_pattern)
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(profile.prompt_suffix)
                .font(.callout)
                .foregroundStyle(.primary)
                .lineLimit(3)
        }
        .padding(12)
        .background(Color(nsColor: .textBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 7))
    }
}
