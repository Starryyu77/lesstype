import AppKit
import Carbon
import Foundation

final class HotKeyManager {
    private var monitors: [Any] = []
    private var activeMode: PipelineMode?
    private var onPress: ((PipelineMode) -> Void)?
    private var onRelease: ((PipelineMode) -> Void)?
    private var onEventDebug: ((String) -> Void)?
    private var dictationHotkey = HotKeyDefinition.defaultDictation
    private var editSelectionHotkey = HotKeyDefinition.defaultEditSelection
    private var hotkeyMode: HotkeyMode = .pressToTalk
    private let carbonMonitor = CarbonHotKeyMonitor()
    private var carbonRegisteredModes = Set<PipelineMode>()
    private var isCaptureSuspended = false

    func start(
        dictationHotkey: String,
        editSelectionHotkey: String,
        hotkeyMode: HotkeyMode,
        onPress: @escaping (PipelineMode) -> Void,
        onRelease: @escaping (PipelineMode) -> Void,
        onEventDebug: @escaping (String) -> Void
    ) {
        stop()
        self.dictationHotkey = HotKeyDefinition(rawValue: dictationHotkey) ?? .defaultDictation
        self.editSelectionHotkey = HotKeyDefinition(rawValue: editSelectionHotkey) ?? .defaultEditSelection
        self.hotkeyMode = hotkeyMode
        self.onPress = onPress
        self.onRelease = onRelease
        self.onEventDebug = onEventDebug

        registerCarbonHotkeys()

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
        carbonMonitor.stop()
        carbonRegisteredModes.removeAll()
        activeMode = nil
    }

    func update(dictationHotkey: String, editSelectionHotkey: String, hotkeyMode: HotkeyMode) {
        self.dictationHotkey = HotKeyDefinition(rawValue: dictationHotkey) ?? .defaultDictation
        self.editSelectionHotkey = HotKeyDefinition(rawValue: editSelectionHotkey) ?? .defaultEditSelection
        self.hotkeyMode = hotkeyMode
        registerCarbonHotkeys()
    }

    func setCaptureSuspended(_ suspended: Bool) {
        isCaptureSuspended = suspended
        carbonMonitor.setCaptureSuspended(suspended)
    }

    private func handle(_ event: NSEvent) {
        guard !isCaptureSuspended else { return }
        onEventDebug?(HotKeyDefinition.describe(event))
        guard let mode = mode(for: event) else { return }
        onEventDebug?("Matched \(mode.rawValue): \(HotKeyDefinition.describe(event))")
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
            if carbonRegisteredModes.contains(.dictation) {
                return nil
            }
            return .dictation
        }
        if editSelectionHotkey.matches(event) {
            if carbonRegisteredModes.contains(.editSelection) {
                return nil
            }
            return .editSelection
        }
        return nil
    }

    private func registerCarbonHotkeys() {
        guard let onPress, let onRelease, let onEventDebug else {
            return
        }
        carbonRegisteredModes = carbonMonitor.start(
            dictationHotkey: dictationHotkey,
            editSelectionHotkey: editSelectionHotkey,
            hotkeyMode: hotkeyMode,
            onPress: onPress,
            onRelease: onRelease,
            onEventDebug: onEventDebug
        )
    }
}

struct HotKeyDefinition: Equatable {
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    private static let matchableModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    static let defaultDictation = HotKeyDefinition(keyCode: 0, modifiers: [.control, .option])
    static let defaultEditSelection = HotKeyDefinition(keyCode: 0, modifiers: [.control, .option, .shift])

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = modifiers.intersection(Self.matchableModifiers)
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
            case "fn", "function", "globe":
                modifiers.insert(.function)
            default:
                return nil
            }
        }
        self.init(keyCode: keyCode, modifiers: modifiers)
    }

    static func from(event: NSEvent) -> HotKeyDefinition? {
        guard event.type == .keyDown, !event.isARepeat else { return nil }
        let modifiers = event.modifierFlags.intersection(Self.matchableModifiers)
        guard !modifiers.isEmpty else { return nil }
        return HotKeyDefinition(keyCode: event.keyCode, modifiers: modifiers)
    }

    func matches(_ event: NSEvent) -> Bool {
        let eventModifiers = event.modifierFlags.intersection(Self.matchableModifiers)
        return event.keyCode == keyCode &&
            eventModifiers == modifiers
    }

    var canRegisterWithCarbon: Bool {
        !modifiers.contains(.function)
    }

    var displayName: String {
        let parts: [String] = [
            modifiers.contains(.function) ? "Fn" : nil,
            modifiers.contains(.control) ? "Control" : nil,
            modifiers.contains(.option) ? "Option" : nil,
            modifiers.contains(.shift) ? "Shift" : nil,
            modifiers.contains(.command) ? "Command" : nil,
            Self.keyName(for: keyCode)
        ].compactMap { $0 }
        return parts.joined(separator: "+")
    }

    var carbonModifiers: UInt32 {
        var value: UInt32 = 0
        if modifiers.contains(.command) {
            value |= UInt32(cmdKey)
        }
        if modifiers.contains(.option) {
            value |= UInt32(optionKey)
        }
        if modifiers.contains(.control) {
            value |= UInt32(controlKey)
        }
        if modifiers.contains(.shift) {
            value |= UInt32(shiftKey)
        }
        return value
    }

    static func describe(_ event: NSEvent) -> String {
        let flags = event.modifierFlags.intersection(matchableModifiers)
        let parts: [String] = [
            flags.contains(.function) ? "Fn" : nil,
            flags.contains(.control) ? "Control" : nil,
            flags.contains(.option) ? "Option" : nil,
            flags.contains(.shift) ? "Shift" : nil,
            flags.contains(.command) ? "Command" : nil,
            keyName(for: event.keyCode)
        ].compactMap { $0 }
        return "\(event.type == .keyDown ? "keyDown" : "keyUp") keyCode=\(event.keyCode) flags=\(parts.joined(separator: "+"))"
    }

    private static func keyCode(for key: String) -> UInt16? {
        if key.hasPrefix("key"), let rawCode = UInt16(key.dropFirst(3)) {
            return rawCode
        }
        if key.hasPrefix("f"), let rawNumber = Int(key.dropFirst()), let code = functionKeyCodes[rawNumber] {
            return code
        }
        switch key {
        case "space":
            return 49
        case "return", "enter":
            return 36
        case "tab":
            return 48
        case "escape", "esc":
            return 53
        case "left", "leftarrow":
            return 123
        case "right", "rightarrow":
            return 124
        case "down", "downarrow":
            return 125
        case "up", "uparrow":
            return 126
        case "delete", "backspace":
            return 51
        default:
            if let digit = digitKeyCodes[key] {
                return digit
            }
            if key.count == 1, let scalar = key.unicodeScalars.first {
                return letterKeyCodes[Character(String(scalar))]
            }
            return nil
        }
    }

    private static func keyName(for keyCode: UInt16) -> String {
        if let match = letterKeyCodes.first(where: { $0.value == keyCode }) {
            return String(match.key).uppercased()
        }
        if let match = digitKeyCodes.first(where: { $0.value == keyCode }) {
            return match.key
        }
        if let match = functionKeyCodes.first(where: { $0.value == keyCode }) {
            return "F\(match.key)"
        }
        switch keyCode {
        case 49:
            return "Space"
        case 36:
            return "Return"
        case 48:
            return "Tab"
        case 53:
            return "Esc"
        case 123:
            return "Left"
        case 124:
            return "Right"
        case 125:
            return "Down"
        case 126:
            return "Up"
        case 51:
            return "Delete"
        default:
            return "Key\(keyCode)"
        }
    }

    private static let letterKeyCodes: [Character: UInt16] = [
        "a": 0, "s": 1, "d": 2, "f": 3, "h": 4, "g": 5, "z": 6, "x": 7,
        "c": 8, "v": 9, "b": 11, "q": 12, "w": 13, "e": 14, "r": 15,
        "y": 16, "t": 17, "o": 31, "u": 32, "i": 34, "p": 35, "l": 37,
        "j": 38, "k": 40, "n": 45, "m": 46
    ]

    private static let digitKeyCodes: [String: UInt16] = [
        "0": 29, "1": 18, "2": 19, "3": 20, "4": 21,
        "5": 23, "6": 22, "7": 26, "8": 28, "9": 25
    ]

    private static let functionKeyCodes: [Int: UInt16] = [
        1: 122, 2: 120, 3: 99, 4: 118, 5: 96,
        6: 97, 7: 98, 8: 100, 9: 101, 10: 109,
        11: 103, 12: 111, 13: 105, 14: 107, 15: 113,
        16: 106, 17: 64, 18: 79, 19: 80, 20: 90
    ]
}

private final class CarbonHotKeyMonitor {
    private static let signature: OSType = 0x4C535459

    private var hotKeyRefs: [EventHotKeyRef] = []
    private var eventHandler: EventHandlerRef?
    private var modeByID: [UInt32: PipelineMode] = [:]
    private var activeMode: PipelineMode?
    private var hotkeyMode: HotkeyMode = .pressToTalk
    private var onPress: ((PipelineMode) -> Void)?
    private var onRelease: ((PipelineMode) -> Void)?
    private var onEventDebug: ((String) -> Void)?
    private var isCaptureSuspended = false

    func start(
        dictationHotkey: HotKeyDefinition,
        editSelectionHotkey: HotKeyDefinition,
        hotkeyMode: HotkeyMode,
        onPress: @escaping (PipelineMode) -> Void,
        onRelease: @escaping (PipelineMode) -> Void,
        onEventDebug: @escaping (String) -> Void
    ) -> Set<PipelineMode> {
        stop()
        self.hotkeyMode = hotkeyMode
        self.onPress = onPress
        self.onRelease = onRelease
        self.onEventDebug = onEventDebug

        guard installHandler() == noErr else {
            return []
        }

        var registeredModes = Set<PipelineMode>()
        if register(dictationHotkey, mode: .dictation, id: 1) {
            registeredModes.insert(.dictation)
        }
        if register(editSelectionHotkey, mode: .editSelection, id: 2) {
            registeredModes.insert(.editSelection)
        }
        return registeredModes
    }

    func stop() {
        for ref in hotKeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotKeyRefs.removeAll()
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
        eventHandler = nil
        modeByID.removeAll()
        activeMode = nil
    }

    func setCaptureSuspended(_ suspended: Bool) {
        isCaptureSuspended = suspended
    }

    private func installHandler() -> OSStatus {
        guard eventHandler == nil else {
            return noErr
        }
        var eventTypes = [
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed)),
            EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyReleased))
        ]
        return eventTypes.withUnsafeMutableBufferPointer { pointer in
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, userData in
                    guard let event, let userData else {
                        return noErr
                    }
                    let monitor = Unmanaged<CarbonHotKeyMonitor>
                        .fromOpaque(userData)
                        .takeUnretainedValue()
                    monitor.handle(event)
                    return noErr
                },
                pointer.count,
                pointer.baseAddress,
                Unmanaged.passUnretained(self).toOpaque(),
                &eventHandler
            )
        }
    }

    private func register(_ definition: HotKeyDefinition, mode: PipelineMode, id: UInt32) -> Bool {
        guard definition.canRegisterWithCarbon else {
            onEventDebug?("Fn hotkey uses NSEvent fallback: \(definition.displayName)")
            return false
        }

        let hotKeyID = EventHotKeyID(signature: Self.signature, id: id)
        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            UInt32(definition.keyCode),
            definition.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &ref
        )
        guard status == noErr, let ref else {
            onEventDebug?("Carbon hotkey registration failed for \(definition.displayName), status=\(status)")
            return false
        }
        hotKeyRefs.append(ref)
        modeByID[id] = mode
        onEventDebug?("Carbon hotkey registered: \(definition.displayName)")
        return true
    }

    private func handle(_ event: EventRef) {
        guard !isCaptureSuspended else { return }
        var hotKeyID = EventHotKeyID()
        let status = GetEventParameter(
            event,
            EventParamName(kEventParamDirectObject),
            EventParamType(typeEventHotKeyID),
            nil,
            MemoryLayout<EventHotKeyID>.size,
            nil,
            &hotKeyID
        )
        guard status == noErr,
              hotKeyID.signature == Self.signature,
              let mode = modeByID[hotKeyID.id] else {
            return
        }

        let kind = GetEventKind(event)
        if kind == UInt32(kEventHotKeyPressed) {
            onEventDebug?("Carbon matched \(mode.rawValue) keyDown")
            handlePress(mode)
        } else if kind == UInt32(kEventHotKeyReleased) {
            onEventDebug?("Carbon matched \(mode.rawValue) keyUp")
            handleRelease(mode)
        }
    }

    private func handlePress(_ mode: PipelineMode) {
        if hotkeyMode == .toggle {
            if let activeMode {
                self.activeMode = nil
                onRelease?(activeMode)
            } else {
                activeMode = mode
                onPress?(mode)
            }
            return
        }

        if activeMode == nil {
            activeMode = mode
            onPress?(mode)
        }
    }

    private func handleRelease(_ mode: PipelineMode) {
        guard hotkeyMode == .pressToTalk else {
            return
        }
        let releaseMode = activeMode ?? mode
        activeMode = nil
        onRelease?(releaseMode)
    }
}
