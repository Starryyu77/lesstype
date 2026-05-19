import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState
    @State private var selection: SettingsPane = .general

    var body: some View {
        HStack(spacing: 0) {
            SettingsSidebar(selection: $selection, appState: appState)
            Rectangle()
                .fill(Color(nsColor: .separatorColor).opacity(0.6))
                .frame(width: 1)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 940, minHeight: 640)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    @ViewBuilder
    private var content: some View {
        switch selection {
        case .general:
            GeneralSettingsView(appState: appState)
        case .asr:
            ASRSettingsView(appState: appState)
        case .llm:
            LLMSettingsView(appState: appState)
        case .hotkeys:
            HotkeySettingsView(appState: appState)
        case .dictionary:
            DictionaryView(appState: appState)
        case .history:
            HistoryView(appState: appState)
        case .styles:
            StyleProfilesView(appState: appState)
        case .permissions:
            PermissionGuideView()
        }
    }
}

private struct SettingsSidebar: View {
    @Binding var selection: SettingsPane
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 5) {
                Text("Lesstype")
                    .font(.system(size: 22, weight: .semibold))
                Text("本地优先语音输入")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.top, 18)

            VStack(alignment: .leading, spacing: 4) {
                ForEach(SettingsPane.allCases) { pane in
                    Button {
                        selection = pane
                    } label: {
                        SettingsSidebarItem(
                            title: pane.title,
                            subtitle: pane.sidebarSubtitle,
                            systemImage: pane.systemImage,
                            isSelected: selection == pane
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)

            Spacer()

            VStack(alignment: .leading, spacing: 8) {
                SettingsStatusLabel(
                    text: appState.phase.menuTitle,
                    systemImage: appState.phase.symbolName,
                    tone: appState.phase == .error ? .danger : appState.phase == .idle ? .neutral : .info
                )
                Text(appState.message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            .padding(14)
        }
        .frame(width: SettingsTheme.sidebarWidth)
        .background(Color(nsColor: .underPageBackgroundColor))
    }
}

private struct SettingsSidebarItem: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(isSelected ? Color.accentColor.opacity(0.14) : Color.clear)
        )
    }
}

private enum SettingsPane: String, CaseIterable, Identifiable {
    case general
    case asr
    case llm
    case hotkeys
    case dictionary
    case history
    case styles
    case permissions

    var id: String { rawValue }

    var title: String {
        switch self {
        case .general:
            return "通用"
        case .asr:
            return "本地识别"
        case .llm:
            return "文本模型"
        case .hotkeys:
            return "快捷键"
        case .dictionary:
            return "个人词典"
        case .history:
            return "历史"
        case .styles:
            return "场景风格"
        case .permissions:
            return "权限"
        }
    }

    var sidebarSubtitle: String {
        switch self {
        case .general:
            return "隐私与本地数据"
        case .asr:
            return "Whisper 配置"
        case .llm:
            return "润色 API"
        case .hotkeys:
            return "全局触发"
        case .dictionary:
            return "术语纠正"
        case .history:
            return "本地记录"
        case .styles:
            return "App 匹配"
        case .permissions:
            return "系统授权"
        }
    }

    var systemImage: String {
        switch self {
        case .general:
            return "gearshape"
        case .asr:
            return "waveform"
        case .llm:
            return "sparkles"
        case .hotkeys:
            return "keyboard"
        case .dictionary:
            return "book"
        case .history:
            return "clock"
        case .styles:
            return "paintpalette"
        case .permissions:
            return "lock.shield"
        }
    }
}
