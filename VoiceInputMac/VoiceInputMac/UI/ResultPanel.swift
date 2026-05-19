import AppKit
import SwiftUI

struct ResultPanel: View {
    let text: String
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "text.badge.xmark")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.orange)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.orange.opacity(0.14))
                    )
                VStack(alignment: .leading, spacing: 3) {
                    Text("无法自动插入")
                        .font(.system(size: 20, weight: .semibold))
                    Text(reason.isEmpty ? "结果已生成，可复制或再次尝试粘贴。" : reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("最终文本")
                    .font(.headline)
                ScrollView {
                    Text(text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                        .padding(12)
                }
                .frame(height: 188)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(nsColor: .separatorColor).opacity(0.55), lineWidth: 1)
                )
            }

            HStack(spacing: 10) {
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Label("复制", systemImage: "doc.on.doc")
                }
                Button {
                    Task {
                        try? await PasteboardInjector(restoreClipboard: { true }).insertText(text)
                    }
                } label: {
                    Label("直接粘贴", systemImage: "arrow.down.doc")
                }
                Button {
                    // Phase 2: re-run LLM with the same context.
                } label: {
                    Label("重新润色", systemImage: "sparkles")
                }
                Spacer()
            }
        }
        .padding(20)
        .frame(width: 500, height: 360)
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

@MainActor
final class ResultPanelPresenter {
    static let shared = ResultPanelPresenter()
    private var window: NSWindow?

    func show(text: String, reason: String) {
        let hosting = NSHostingView(rootView: ResultPanel(text: text, reason: reason))
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 500, height: 360),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Lesstype Result"
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.contentView = hosting
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
