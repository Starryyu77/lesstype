import AVFoundation
import AppKit
import ApplicationServices
import SwiftUI

struct PermissionGuideView: View {
    private var microphoneStatus: String {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return "已允许"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限制"
        case .notDetermined:
            return "未决定"
        @unknown default:
            return "未知"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label("麦克风权限：\(microphoneStatus)", systemImage: "mic")
            Label("辅助功能权限：\(AXIsProcessTrusted() ? "已允许" : "未允许")", systemImage: "accessibility")
            Label("输入监听权限：\(CGPreflightListenEventAccess() ? "已允许" : "未允许")", systemImage: "keyboard")

            Text("需要麦克风权限才能录音；需要辅助功能权限才能把文本插入当前 App；全局按住快捷键在部分系统设置下还需要输入监听权限。")
                .foregroundStyle(.secondary)

            Text("开发版如果每次重新打包并使用 ad-hoc 签名，macOS 可能会把它当成新 App 并重新要求授权。稳定使用时请固定同一个 .app，或使用 Apple Development / Developer ID 证书签名。")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack {
                Button("打开麦克风设置") {
                    openPrivacyPane("Privacy_Microphone")
                }
                Button("打开辅助功能设置") {
                    openPrivacyPane("Privacy_Accessibility")
                }
                Button("打开输入监听设置") {
                    openPrivacyPane("Privacy_ListenEvent")
                }
                Button("请求输入监听权限") {
                    _ = CGRequestListenEventAccess()
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func openPrivacyPane(_ pane: String) {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
            NSWorkspace.shared.open(url)
        }
    }
}
