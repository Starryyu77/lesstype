import AppKit
import SwiftUI

struct DictationOverlay: View {
    @ObservedObject var model: DictationOverlayModel

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: model.phase.symbolName)
                .font(.title2)
                .foregroundStyle(model.phase == .error ? .red : .primary)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 7) {
                Text(model.message)
                    .font(.headline)
                if model.phase == .recording {
                    VoiceLevelBars(level: model.level)
                } else if model.phase == .transcribing || model.phase == .polishing || model.phase == .injecting {
                    ProcessingDots(phase: model.phase)
                } else {
                    Text("Esc 取消")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(16)
        .frame(minWidth: 320)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 20)
    }
}

@MainActor
final class DictationOverlayModel: ObservableObject {
    @Published var message: String = ""
    @Published var phase: AppPhase = .idle
    @Published var level: Float = 0
}

struct VoiceLevelBars: View {
    let level: Float

    var body: some View {
        HStack(alignment: .center, spacing: 3) {
            ForEach(0..<18, id: \.self) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.accentColor.opacity(0.35 + Double(index % 4) * 0.12))
                    .frame(width: 4, height: barHeight(at: index))
                    .animation(.easeOut(duration: 0.08), value: level)
            }
        }
        .frame(height: 26, alignment: .center)
    }

    private func barHeight(at index: Int) -> CGFloat {
        let base = CGFloat(max(level, 0.04))
        let wave = CGFloat([0.35, 0.65, 1.0, 0.75, 0.45, 0.85][index % 6])
        return min(max(5 + base * wave * 34, 5), 32)
    }
}

struct ProcessingDots: View {
    let phase: AppPhase
    @State private var animate = false

    var body: some View {
        HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { index in
                Circle()
                    .fill(color)
                    .frame(width: 7, height: 7)
                    .scaleEffect(animate ? 1.2 : 0.55)
                    .opacity(animate ? 0.95 : 0.35)
                    .animation(
                        .easeInOut(duration: 0.55)
                            .repeatForever()
                            .delay(Double(index) * 0.1),
                        value: animate
                    )
            }
        }
        .frame(height: 26)
        .onAppear { animate = true }
    }

    private var color: Color {
        switch phase {
        case .polishing:
            return .purple
        case .injecting:
            return .green
        default:
            return .accentColor
        }
    }
}

@MainActor
final class DictationOverlayPresenter {
    static let shared = DictationOverlayPresenter()
    private let model = DictationOverlayModel()
    private var panel: NSPanel?

    func show(message: String, phase: AppPhase) {
        model.message = message
        model.phase = phase
        if phase != .recording {
            model.level = 0
        }
        let hosting = NSHostingView(rootView: DictationOverlay(model: model))
        if panel == nil {
            let panel = NSPanel(
                contentRect: NSRect(x: 0, y: 0, width: 360, height: 112),
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
            panel?.setFrameOrigin(NSPoint(x: frame.midX - 180, y: frame.maxY - 160))
        }
        panel?.orderFrontRegardless()
    }

    func updateLevel(_ level: Float) {
        model.level = level
    }

    func hide(after delay: TimeInterval = 0) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
            self?.panel?.orderOut(nil)
        }
    }
}
