import AppKit
import SwiftUI

struct DictationOverlay: View {
    let message: String
    let phase: AppPhase

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: phase.symbolName)
                .font(.title2)
                .foregroundStyle(phase == .error ? .red : .primary)
            VStack(alignment: .leading, spacing: 3) {
                Text(message)
                    .font(.headline)
                Text("Esc 取消")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .frame(minWidth: 260)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 20)
    }
}

@MainActor
final class DictationOverlayPresenter {
    static let shared = DictationOverlayPresenter()
    private var panel: NSPanel?

    func show(message: String, phase: AppPhase) {
        let hosting = NSHostingView(rootView: DictationOverlay(message: message, phase: phase))
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 300, height: 96),
                styleMask: [.nonactivatingPanel, .hudWindow],
                backing: .buffered,
                defer: false
            )
            panel.level = .floating
            panel.isReleasedWhenClosed = false
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            self.panel = panel
        }
        panel?.contentView = hosting
        if let screen = NSScreen.main {
            let frame = screen.visibleFrame
            panel?.setFrameOrigin(NSPoint(x: frame.midX - 150, y: frame.maxY - 150))
        }
        panel?.orderFrontRegardless()
    }

    func hide(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }
}

