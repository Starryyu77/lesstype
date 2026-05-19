import AppKit
import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject var appState: AppState
    @State private var captureTarget: PipelineMode?

    var body: some View {
        Form {
            Section("全局快捷键") {
                HotkeyRecorderRow(
                    title: "普通听写",
                    value: appState.config.dictationHotkey,
                    mode: .dictation,
                    captureTarget: $captureTarget,
                    appState: appState
                )
                HotkeyRecorderRow(
                    title: "编辑选中文本",
                    value: appState.config.editSelectionHotkey,
                    mode: .editSelection,
                    captureTarget: $captureTarget,
                    appState: appState
                )
                if !appState.hotkeySettingsMessage.isEmpty {
                    Text(appState.hotkeySettingsMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Picker("录音模式", selection: binding(\.hotkeyMode)) {
                ForEach(HotkeyMode.allCases) { mode in
                    Text(mode.title).tag(mode)
                }
            }
            Text(appState.config.hotkeyMode == .toggle ? "当前：按一次开始录音，再按一次停止、识别并输入。" : "当前：按住快捷键录音，松开后识别并输入。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("推荐使用 Ctrl+Option+A。Fn 键在部分 macOS 键盘设置下不会作为普通 modifier 传给应用；如果 Fn+A 没反应，请改用更稳的备用热键。")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("点击“录制”后按下新组合键。需要至少包含一个修饰键，例如 Control、Option、Command、Shift 或 Fn。按 Esc 可取消录制。")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                Text("最近捕获按键")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(appState.lastHotkeyEvent)
                    .font(.system(.caption, design: .monospaced))
                    .textSelection(.enabled)
            }

            HStack {
                Button("使用 Fn+A") {
                    appState.useFnHotkeys()
                }
                Button("使用更稳的 Ctrl+Option+A") {
                    appState.useReliableFallbackHotkeys()
                }
                Button("使用按一下开始/结束") {
                    appState.useToggleRecordingMode()
                }
            }

            Button("保存快捷键设置") {
                appState.saveConfig()
            }
        }
        .padding()
    }

    private func binding<Value>(_ keyPath: WritableKeyPath<AppConfig, Value>) -> Binding<Value> {
        Binding(
            get: { appState.config[keyPath: keyPath] },
            set: {
                appState.config[keyPath: keyPath] = $0
                appState.saveConfig()
            }
        )
    }
}

private struct HotkeyRecorderRow: View {
    let title: String
    let value: String
    let mode: PipelineMode
    @Binding var captureTarget: PipelineMode?
    @ObservedObject var appState: AppState

    private var isCapturing: Bool {
        captureTarget == mode
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(title)
                .frame(width: 110, alignment: .leading)
            Text(isCapturing ? "请按新的快捷键..." : displayValue)
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(isCapturing ? Color.accentColor : Color.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(nsColor: .textBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button(isCapturing ? "取消" : "录制") {
                toggleCapture()
            }
        }
        .background(
            HotkeyCaptureView(
                isCapturing: isCapturing,
                onCapture: { event in
                    guard let definition = HotKeyDefinition.from(event: event) else {
                        appState.hotkeySettingsMessage = "快捷键需要至少包含一个修饰键。"
                        return
                    }
                    appState.assignHotkey(definition, to: mode)
                    captureTarget = nil
                    appState.setHotkeyCaptureActive(false)
                },
                onCancel: {
                    captureTarget = nil
                    appState.setHotkeyCaptureActive(false)
                    appState.hotkeySettingsMessage = "已取消录制。"
                }
            )
            .frame(width: 0, height: 0)
        )
    }

    private var displayValue: String {
        HotKeyDefinition(rawValue: value)?.displayName ?? value
    }

    private func toggleCapture() {
        if isCapturing {
            captureTarget = nil
            appState.setHotkeyCaptureActive(false)
            appState.hotkeySettingsMessage = "已取消录制。"
        } else {
            captureTarget = mode
            appState.setHotkeyCaptureActive(true)
            appState.hotkeySettingsMessage = "正在录制 \(title) 快捷键。"
        }
    }
}

private struct HotkeyCaptureView: NSViewRepresentable {
    let isCapturing: Bool
    let onCapture: (NSEvent) -> Void
    let onCancel: () -> Void

    func makeNSView(context: Context) -> HotkeyCaptureNSView {
        let view = HotkeyCaptureNSView()
        view.onCapture = onCapture
        view.onCancel = onCancel
        view.isCapturing = isCapturing
        return view
    }

    func updateNSView(_ nsView: HotkeyCaptureNSView, context: Context) {
        nsView.onCapture = onCapture
        nsView.onCancel = onCancel
        nsView.isCapturing = isCapturing
        if isCapturing {
            DispatchQueue.main.async {
                nsView.window?.makeFirstResponder(nsView)
            }
        }
    }
}

private final class HotkeyCaptureNSView: NSView {
    var isCapturing = false
    var onCapture: ((NSEvent) -> Void)?
    var onCancel: (() -> Void)?

    override var acceptsFirstResponder: Bool { true }

    override func keyDown(with event: NSEvent) {
        guard isCapturing else {
            super.keyDown(with: event)
            return
        }
        if event.keyCode == 53 {
            onCancel?()
            return
        }
        guard !event.isARepeat else { return }
        onCapture?(event)
    }
}
