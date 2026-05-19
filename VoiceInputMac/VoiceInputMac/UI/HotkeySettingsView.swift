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
            Text("推荐使用 Ctrl+Option+A。Fn / Control / Option 组合键依赖输入监听权限；如果录制或触发失败，请在 Permissions 页请求输入监听权限。")
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
    private var monitors: [Any] = []
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isActive = false
    private var captureMode: PipelineMode?
    private weak var captureAppState: AppState?
    private var captureOnFinish: (() -> Void)?

    func start(mode: PipelineMode, appState: AppState, onFinish: @escaping () -> Void) {
        stop(appState: nil)
        isActive = true
        captureMode = mode
        captureAppState = appState
        captureOnFinish = onFinish
        if let local = NSEvent.addLocalMonitorForEvents(matching: .keyDown, handler: { [weak self, weak appState] event in
            Task { @MainActor in
                guard let self, let appState else { return }
                self.handle(event, mode: mode, appState: appState, onFinish: onFinish)
            }
            return nil
        }) {
            monitors.append(local)
        }

        if let global = NSEvent.addGlobalMonitorForEvents(matching: .keyDown, handler: { [weak self, weak appState] event in
            Task { @MainActor in
                guard let self, let appState else { return }
                self.handle(event, mode: mode, appState: appState, onFinish: onFinish)
            }
        }) {
            monitors.append(global)
        }
        startEventTap()
    }

    func stop(appState: AppState?) {
        isActive = false
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        stopEventTap()
        captureMode = nil
        captureAppState = nil
        captureOnFinish = nil
        appState?.setHotkeyCaptureActive(false)
    }

    private func startEventTap() {
        guard CGPreflightListenEventAccess() || CGRequestListenEventAccess() else {
            captureAppState?.hotkeySettingsMessage = "录制 Fn / Control / Option 组合键需要输入监听权限。"
            return
        }

        let mask = CGEventMask(1) << CGEventType.keyDown.rawValue
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<HotkeyCaptureMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            Task { @MainActor in
                monitor.handle(cgEvent: event, type: type)
            }
            return Unmanaged.passUnretained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            captureAppState?.hotkeySettingsMessage = "无法启动底层键盘监听。请在系统设置中允许输入监听权限。"
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
    }

    private func stopEventTap() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }

    private func handle(
        _ event: NSEvent,
        mode: PipelineMode,
        appState: AppState,
        onFinish: () -> Void
    ) {
        guard isActive else { return }
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

    private func handle(
        cgEvent: CGEvent,
        type: CGEventType
    ) {
        guard isActive,
              type == .keyDown,
              let mode = captureMode,
              let appState = captureAppState,
              let onFinish = captureOnFinish else { return }
        let keyCode = UInt16(cgEvent.getIntegerValueField(.keyboardEventKeycode))
        if keyCode == 53 {
            stop(appState: appState)
            appState.hotkeySettingsMessage = "已取消录制。"
            onFinish()
            return
        }
        guard let definition = HotKeyDefinition.from(cgEvent: cgEvent, type: type) else {
            appState.hotkeySettingsMessage = "快捷键需要至少包含一个修饰键。"
            return
        }
        appState.assignHotkey(definition, to: mode)
        stop(appState: appState)
        onFinish()
    }

    deinit {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
    }
}
