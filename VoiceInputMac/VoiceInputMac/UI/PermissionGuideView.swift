import AVFoundation
import AppKit
import ApplicationServices
import SwiftUI

struct PermissionGuideView: View {
    private var microphoneStatus: PermissionStatus {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return .allowed
        case .denied:
            return .denied
        case .restricted:
            return .restricted
        case .notDetermined:
            return .unknown
        @unknown default:
            return .unknown
        }
    }

    var body: some View {
        SettingsPage(
            title: "权限",
            subtitle: "macOS 需要显式授权麦克风、辅助功能和输入监听。",
            systemImage: "lock.shield"
        ) {
            SettingsPanel("权限状态") {
                PermissionRow(
                    title: "麦克风",
                    detail: "用于本地录音和保存临时 WAV。",
                    systemImage: "mic",
                    status: microphoneStatus
                ) {
                    openPrivacyPane("Privacy_Microphone")
                }
                SettingsDivider()
                PermissionRow(
                    title: "辅助功能",
                    detail: "用于把文本写入当前 App，以及读取选中文本。",
                    systemImage: "accessibility",
                    status: AccessibilityPermission.isTrusted() ? .allowed : .denied
                ) {
                    openPrivacyPane("Privacy_Accessibility")
                }
                SettingsDivider()
                PermissionRow(
                    title: "输入监听",
                    detail: "Fn / Control / Option 等全局快捷键需要它。",
                    systemImage: "keyboard",
                    status: CGPreflightListenEventAccess() ? .allowed : .denied
                ) {
                    openPrivacyPane("Privacy_ListenEvent")
                }
            }

            SettingsPanel("请求授权") {
                HStack(spacing: 10) {
                    Button {
                        _ = AccessibilityPermission.isTrusted(prompt: true)
                    } label: {
                        Label("请求辅助功能权限", systemImage: "accessibility")
                    }
                    Button {
                        _ = CGRequestListenEventAccess()
                    } label: {
                        Label("请求输入监听权限", systemImage: "keyboard")
                    }
                    Spacer()
                }
                Text("如果开发版重新打包后权限失效，请删除系统设置里的旧 VoiceInputMac 项，再重新添加当前 dist/VoiceInputMac.app。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func openPrivacyPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}

private enum PermissionStatus {
    case allowed
    case denied
    case restricted
    case unknown

    var title: String {
        switch self {
        case .allowed:
            return "已允许"
        case .denied:
            return "未允许"
        case .restricted:
            return "受限制"
        case .unknown:
            return "未决定"
        }
    }

    var tone: SettingsStatusLabel.Tone {
        switch self {
        case .allowed:
            return .success
        case .denied:
            return .danger
        case .restricted:
            return .warning
        case .unknown:
            return .neutral
        }
    }
}

private struct PermissionRow: View {
    let title: String
    let detail: String
    let systemImage: String
    let status: PermissionStatus
    let openAction: () -> Void

    var body: some View {
        SettingsRow(title, detail: detail) {
            HStack(spacing: 8) {
                SettingsStatusLabel(text: status.title, systemImage: systemImage, tone: status.tone)
                Button("打开设置", action: openAction)
            }
        }
    }
}
