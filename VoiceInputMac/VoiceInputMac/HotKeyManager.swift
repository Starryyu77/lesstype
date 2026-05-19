import AppKit
import Foundation

final class HotKeyManager {
    private var monitors: [Any] = []
    private var activeMode: PipelineMode?
    private var onPress: ((PipelineMode) -> Void)?
    private var onRelease: ((PipelineMode) -> Void)?
    private var dictationHotkey = HotKeyDefinition.defaultDictation
    private var editSelectionHotkey = HotKeyDefinition.defaultEditSelection
    private var hotkeyMode: HotkeyMode = .pressToTalk

    func start(
        dictationHotkey: String,
        editSelectionHotkey: String,
        hotkeyMode: HotkeyMode,
        onPress: @escaping (PipelineMode) -> Void,
        onRelease: @escaping (PipelineMode) -> Void
    ) {
        stop()
        self.dictationHotkey = HotKeyDefinition(rawValue: dictationHotkey) ?? .defaultDictation
        self.editSelectionHotkey = HotKeyDefinition(rawValue: editSelectionHotkey) ?? .defaultEditSelection
        self.hotkeyMode = hotkeyMode
        self.onPress = onPress
        self.onRelease = onRelease

        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handle(event)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp], handler: handler) {
            monitors.append(global)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { event in
            handler(event)
            return event
        }
        if let local {
            monitors.append(local)
        }
    }

    func stop() {
        for monitor in monitors {
            NSEvent.removeMonitor(monitor)
        }
        monitors.removeAll()
        activeMode = nil
    }

    func update(dictationHotkey: String, editSelectionHotkey: String, hotkeyMode: HotkeyMode) {
        self.dictationHotkey = HotKeyDefinition(rawValue: dictationHotkey) ?? .defaultDictation
        self.editSelectionHotkey = HotKeyDefinition(rawValue: editSelectionHotkey) ?? .defaultEditSelection
        self.hotkeyMode = hotkeyMode
    }

    private func handle(_ event: NSEvent) {
        guard let mode = mode(for: event) else { return }
        if hotkeyMode == .toggle {
            guard event.type == .keyDown, !event.isARepeat else { return }
            if let activeMode {
                self.activeMode = nil
                onRelease?(activeMode)
            } else {
                activeMode = mode
                onPress?(mode)
            }
            return
        }

        if event.type == .keyDown, !event.isARepeat {
            if activeMode == nil {
                activeMode = mode
                onPress?(mode)
            }
        } else if event.type == .keyUp {
            let releaseMode = activeMode ?? mode
            activeMode = nil
            onRelease?(releaseMode)
        }
    }

    private func mode(for event: NSEvent) -> PipelineMode? {
        if dictationHotkey.matches(event) {
            return .dictation
        }
        if editSelectionHotkey.matches(event) {
            return .editSelection
        }
        return nil
    }
}

struct HotKeyDefinition: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags

    static let defaultDictation = HotKeyDefinition(keyCode: 49, modifiers: [.option])
    static let defaultEditSelection = HotKeyDefinition(keyCode: 49, modifiers: [.option, .shift])

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(.deviceIndependentFlagsMask)
    }

    init?(rawValue: String) {
        let pieces = rawValue
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        guard let key = pieces.last, let keyCode = Self.keyCode(for: key) else {
            return nil
        }
        var modifiers = NSEvent.ModifierFlags()
        for piece in pieces.dropLast() {
            switch piece {
            case "option", "opt", "alt":
                modifiers.insert(.option)
            case "shift":
                modifiers.insert(.shift)
            case "command", "cmd":
                modifiers.insert(.command)
            case "control", "ctrl":
                modifiers.insert(.control)
            default:
                return nil
            }
        }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    func matches(_ event: NSEvent) -> Bool {
        event.keyCode == keyCode &&
            event.modifierFlags.intersection(.deviceIndependentFlagsMask) == modifiers
    }

    private static func keyCode(for key: String) -> UInt16? {
        switch key {
        case "space":
            return 49
        case "return", "enter":
            return 36
        case "tab":
            return 48
        case "escape", "esc":
            return 53
        default:
            if key.count == 1, let scalar = key.unicodeScalars.first {
                return letterKeyCodes[Character(String(scalar))]
            }
            return nil
        }
    }

    private static let letterKeyCodes: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37,
        "j": 38, "k": 40, "n": 45, "m": 46
    ]
}
