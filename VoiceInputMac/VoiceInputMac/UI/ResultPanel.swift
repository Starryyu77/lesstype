import AppKit
import SwiftUI

struct ResultPanel: View {
    let text: String
    let reason: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("无法自动插入")
                .font(.headline)
            if !reason.isEmpty {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ScrollView {
                Text(text)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
                    .padding(10)
            }
            .frame(height: 180)
            .background(Color(nsColor: .textBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            HStack {
                Button("复制") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
                Button("直接粘贴") {
                    Task {
                        try? await PasteboardInjector(restoreClipboard: { true }).insertText(text)
                    }
                }
                Button("重新润色") {
                    // Phase 2: re-run LLM with the same context.
                }
            }
        }
        .padding()
        .frame(width: 460, height: 340)
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
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
                styleMask: [.titled, .closable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "VoiceInputMac Result"
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.contentView = hosting
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}

