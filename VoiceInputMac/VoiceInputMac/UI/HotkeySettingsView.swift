import AppKit
import SwiftUI

struct HotkeySettingsView: View {
    @ObservedObject var appState: AppState
    @State private var captureTarget: PipelineMode?
    @StateObject private var captureMonitor = HotkeyCaptureMonitor()

    var body: some View {
        Form {
            Section("全局快捷键") {
                HotkeyRecorderRow(
                    title: "普通听写",
                    value: appState.config.dictationHotkey,
                    mode: .dictation,
                    captureTarget: $captureTarget,
                    appState: appState,
                    onStartCapture: { startCapture(.dictation, title: "普通听写") },
                    onCancelCapture: cancelCapture
                )
                HotkeyRecorderRow(
                    title: "编辑选中文本",
                    value: appState.config.editSelectionHotkey,
                    mode: .editSelection,
                    captureTarget: $captureTarget,
                    appState: appState,
                    onStartCapture: { startCapture(.editSelection, title: "编辑选中文本") },
                    onCancelCapture: cancelCapture
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
        .onDisappear {
            captureMonitor.stop(appState: appState)
            captureTarget = nil
        }
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

    private func startCapture(_ mode: PipelineMode, title: String) {
        captureTarget = mode
        appState.hotkeySettingsMessage = "正在录制 \(title) 快捷键。"
        appState.setHotkeyCaptureActive(true)
        captureMonitor.start(mode: mode, appState: appState) {
            captureTarget = nil
        }
    }

    private func cancelCapture() {
        captureMonitor.stop(appState: appState)
        captureTarget = nil
        appState.hotkeySettingsMessage = "已取消录制。"
    }
}

private struct HotkeyRecorderRow: View {
    let title: String
    let value: String
    let mode: PipelineMode
    @Binding var captureTarget: PipelineMode?
    @ObservedObject var appState: AppState
    let onStartCapture: () -> Void
    let onCancelCapture: () -> Void

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
    }

    private var displayValue: String {
        HotKeyDefinition(rawValue: value)?.displayName ?? value
    }

    private func toggleCapture() {
        if isCapturing {
            onCancelCapture()
        } else {
            onStartCapture()
        }
    }
}

@MainActor
private final class HotkeyCaptureMonitor: ObservableObject {
    private var monitor: Any?

    func start(mode: PipelineMode, appState: AppState, onFinish: @escaping () -> Void) {
        stop(appState: nil)
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self, weak appState] event in
            Task { @MainActor in
                guard let self, let appState else { return }
                self.handle(event, mode: mode, appState: appState, onFinish: onFinish)
            }
            return nil
        }
    }

    func stop(appState: AppState?) {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
        appState?.setHotkeyCaptureActive(false)
    }

    private func handle(
        _ event: NSEvent,
        mode: PipelineMode,
        appState: AppState,
        onFinish: () -> Void
    ) {
        if event.keyCode == 53 {
            stop(appState: appState)
            appState.hotkeySettingsMessage = "已取消录制。"
            onFinish()
            return
        }
        guard !event.isARepeat else { return }
        guard let definition = HotKeyDefinition.from(event: event) else {
            appState.hotkeySettingsMessage = "快捷键需要至少包含一个修饰键。"
            return
        }

        appState.assignHotkey(definition, to: mode)
        stop(appState: appState)
        onFinish()
    }

    deinit {
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
