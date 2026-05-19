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
    private let eventTapMonitor = CGEventHotKeyMonitor()
    private var eventTapRegisteredModes = Set<PipelineMode>()
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

        registerHotkeys()

        let handler: (NSEvent) -> Void = { [weak self] event in
            self?.handle(event)
        }
        if let global = NSEvent.addGlobalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged], handler: handler) {
            monitors.append(global)
        }
        let local = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { event in
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
        eventTapMonitor.stop()
        eventTapRegisteredModes.removeAll()
        activeMode = nil
    }

    func update(dictationHotkey: String, editSelectionHotkey: String, hotkeyMode: HotkeyMode) {
        self.dictationHotkey = HotKeyDefinition(rawValue: dictationHotkey) ?? .defaultDictation
        self.editSelectionHotkey = HotKeyDefinition(rawValue: editSelectionHotkey) ?? .defaultEditSelection
        self.hotkeyMode = hotkeyMode
        registerHotkeys()
    }

    func setCaptureSuspended(_ suspended: Bool) {
        isCaptureSuspended = suspended
        carbonMonitor.setCaptureSuspended(suspended)
        eventTapMonitor.setCaptureSuspended(suspended)
    }

    private func handle(_ event: NSEvent) {
        guard !isCaptureSuspended else { return }
        onEventDebug?(HotKeyDefinition.describe(event))
        if event.type == .flagsChanged {
            handleFlagsChanged(event)
            return
        }
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

    private func handleFlagsChanged(_ event: NSEvent) {
        if let mode = mode(for: event) {
            onEventDebug?("Matched \(mode.rawValue): \(HotKeyDefinition.describe(event))")
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
            return
        }

        guard hotkeyMode == .pressToTalk,
              let activeMode,
              hotkeyDefinition(for: activeMode).isModifierOnly else {
            return
        }
        self.activeMode = nil
        onRelease?(activeMode)
    }

    private func mode(for event: NSEvent) -> PipelineMode? {
        if dictationHotkey.matches(event) {
            if eventTapRegisteredModes.contains(.dictation) || carbonRegisteredModes.contains(.dictation) {
                return nil
            }
            return .dictation
        }
        if editSelectionHotkey.matches(event) {
            if eventTapRegisteredModes.contains(.editSelection) || carbonRegisteredModes.contains(.editSelection) {
                return nil
            }
            return .editSelection
        }
        return nil
    }

    private func hotkeyDefinition(for mode: PipelineMode) -> HotKeyDefinition {
        switch mode {
        case .dictation:
            return dictationHotkey
        case .editSelection:
            return editSelectionHotkey
        }
    }

    private func registerHotkeys() {
        guard let onPress, let onRelease, let onEventDebug else {
            return
        }
        carbonMonitor.stop()
        carbonRegisteredModes.removeAll()
        eventTapRegisteredModes = eventTapMonitor.start(
            dictationHotkey: dictationHotkey,
            editSelectionHotkey: editSelectionHotkey,
            hotkeyMode: hotkeyMode,
            onPress: onPress,
            onRelease: onRelease,
            onEventDebug: onEventDebug
        )
        guard eventTapRegisteredModes.isEmpty else {
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
    static let modifierOnlyKeyCode = UInt16.max
    let keyCode: UInt16
    let modifiers: NSEvent.ModifierFlags
    private static let matchableModifiers: NSEvent.ModifierFlags = [.command, .option, .control, .shift, .function]

    static let defaultDictation = HotKeyDefinition(keyCode: 0, modifiers: [.control, .option])
    static let defaultEditSelection = HotKeyDefinition(keyCode: 0, modifiers: [.control, .option, .shift])

    init(keyCode: UInt16, modifiers: NSEvent.ModifierFlags) {
        self.keyCode = keyCode
        self.modifiers = Self.normalizedModifiers(from: modifiers)
    }

    init?(rawValue: String) {
        let pieces = rawValue
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty }
        var modifiers = NSEvent.ModifierFlags()
        var keyCode: UInt16?
        for piece in pieces {
            if let modifier = Self.modifier(for: piece) {
                modifiers.insert(modifier)
            } else if keyCode == nil, let code = Self.keyCode(for: piece) {
                keyCode = code
            } else {
                return nil
            }
        }
        guard !modifiers.isEmpty else { return nil }
        self.init(keyCode: keyCode ?? Self.modifierOnlyKeyCode, modifiers: modifiers)
    }

    static func from(event: NSEvent) -> HotKeyDefinition? {
        let modifiers = normalizedModifiers(from: event.modifierFlags)
        guard !modifiers.isEmpty else { return nil }
        if event.type == .flagsChanged {
            return HotKeyDefinition(keyCode: Self.modifierOnlyKeyCode, modifiers: modifiers)
        }
        guard event.type == .keyDown, !event.isARepeat else { return nil }
        return HotKeyDefinition(keyCode: event.keyCode, modifiers: modifiers)
    }

    func matches(_ event: NSEvent) -> Bool {
        let eventModifiers = Self.normalizedModifiers(from: event.modifierFlags)
        if isModifierOnly {
            return event.type == .flagsChanged &&
                eventModifiers == modifiers
        }
        guard event.type == .keyDown || event.type == .keyUp else { return false }
        return event.keyCode == keyCode &&
            eventModifiers == modifiers
    }

    func matches(_ event: CGEvent, type: CGEventType) -> Bool {
        let eventKeyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))
        let eventModifiers = Self.normalizedModifiers(from: event.flags)
        if isModifierOnly {
            return type == .flagsChanged &&
                eventModifiers == modifiers
        }
        guard type == .keyDown || type == .keyUp else { return false }
        return eventKeyCode == keyCode &&
            eventModifiers == modifiers
    }

    var canRegisterWithCarbon: Bool {
        !isModifierOnly && !modifiers.contains(.function)
    }

    var isModifierOnly: Bool {
        keyCode == Self.modifierOnlyKeyCode
    }

    var modifierCount: Int {
        Self.modifierNames(for: modifiers).count
    }

    var displayName: String {
        var parts = Self.modifierNames(for: modifiers)
        if !isModifierOnly {
            parts.append(Self.keyName(for: keyCode))
        }
        return parts.joined(separator: "+")
    }

    private static func modifierNames(for modifiers: NSEvent.ModifierFlags) -> [String] {
        [
            modifiers.contains(.function) ? "Fn" : nil,
            modifiers.contains(.control) ? "Control" : nil,
            modifiers.contains(.option) ? "Option" : nil,
            modifiers.contains(.shift) ? "Shift" : nil,
            modifiers.contains(.command) ? "Command" : nil
        ].compactMap { $0 }
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
        let flags = normalizedModifiers(from: event.modifierFlags)
        var parts = modifierNames(for: flags)
        if event.type != .flagsChanged {
            parts.append(keyName(for: event.keyCode))
        }
        return "\(eventTypeName(event.type)) keyCode=\(event.keyCode) flags=\(parts.joined(separator: "+"))"
    }

    static func from(cgEvent: CGEvent, type: CGEventType) -> HotKeyDefinition? {
        let modifiers = normalizedModifiers(from: cgEvent.flags)
        guard !modifiers.isEmpty else { return nil }
        if type == .flagsChanged {
            return HotKeyDefinition(keyCode: Self.modifierOnlyKeyCode, modifiers: modifiers)
        }
        guard type == .keyDown,
              cgEvent.getIntegerValueField(.keyboardEventAutorepeat) == 0 else {
            return nil
        }
        let keyCode = UInt16(cgEvent.getIntegerValueField(.keyboardEventKeycode))
        return HotKeyDefinition(keyCode: keyCode, modifiers: modifiers)
    }

    static func describe(cgEvent: CGEvent, type: CGEventType) -> String {
        let flags = normalizedModifiers(from: cgEvent.flags)
        let keyCode = UInt16(cgEvent.getIntegerValueField(.keyboardEventKeycode))
        var parts = modifierNames(for: flags)
        if type != .flagsChanged {
            parts.append(keyName(for: keyCode))
        }
        let typeName = cgEventTypeName(type)
        return "\(typeName) keyCode=\(keyCode) flags=\(parts.joined(separator: "+"))"
    }

    private static func modifier(for piece: String) -> NSEvent.ModifierFlags? {
        switch piece {
        case "option", "opt", "alt":
            return .option
        case "shift":
            return .shift
        case "command", "cmd":
            return .command
        case "control", "ctrl":
            return .control
        case "fn", "function", "globe":
            return .function
        default:
            return nil
        }
    }

    private static func eventTypeName(_ type: NSEvent.EventType) -> String {
        switch type {
        case .keyDown:
            return "keyDown"
        case .keyUp:
            return "keyUp"
        case .flagsChanged:
            return "flagsChanged"
        default:
            return "\(type.rawValue)"
        }
    }

    private static func cgEventTypeName(_ type: CGEventType) -> String {
        switch type {
        case .keyDown:
            return "keyDown"
        case .keyUp:
            return "keyUp"
        case .flagsChanged:
            return "flagsChanged"
        default:
            return "\(type.rawValue)"
        }
    }

    private static func normalizedModifiers(from flags: NSEvent.ModifierFlags) -> NSEvent.ModifierFlags {
        flags
            .intersection(.deviceIndependentFlagsMask)
            .intersection(matchableModifiers)
    }

    private static func normalizedModifiers(from flags: CGEventFlags) -> NSEvent.ModifierFlags {
        var result = NSEvent.ModifierFlags()
        if flags.contains(.maskCommand) {
            result.insert(.command)
        }
        if flags.contains(.maskAlternate) {
            result.insert(.option)
        }
        if flags.contains(.maskControl) {
            result.insert(.control)
        }
        if flags.contains(.maskShift) {
            result.insert(.shift)
        }
        if flags.contains(.maskSecondaryFn) {
            result.insert(.function)
        }
        return result
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

private final class CGEventHotKeyMonitor {
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var dictationHotkey = HotKeyDefinition.defaultDictation
    private var editSelectionHotkey = HotKeyDefinition.defaultEditSelection
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
        guard CGPreflightListenEventAccess() || CGRequestListenEventAccess() else {
            onEventDebug("CGEventTap needs Input Monitoring permission")
            return []
        }

        self.dictationHotkey = dictationHotkey
        self.editSelectionHotkey = editSelectionHotkey
        self.hotkeyMode = hotkeyMode
        self.onPress = onPress
        self.onRelease = onRelease
        self.onEventDebug = onEventDebug

        let mask =
            (CGEventMask(1) << CGEventType.keyDown.rawValue) |
            (CGEventMask(1) << CGEventType.keyUp.rawValue) |
            (CGEventMask(1) << CGEventType.flagsChanged.rawValue)
        let callback: CGEventTapCallBack = { _, type, event, userInfo in
            guard let userInfo else {
                return Unmanaged.passUnretained(event)
            }
            let monitor = Unmanaged<CGEventHotKeyMonitor>
                .fromOpaque(userInfo)
                .takeUnretainedValue()
            monitor.handle(type: type, event: event)
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
            onEventDebug("CGEventTap registration failed")
            return []
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        onEventDebug("CGEventTap hotkeys registered")
        return [.dictation, .editSelection]
    }

    func stop() {
        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        activeMode = nil
    }

    func setCaptureSuspended(_ suspended: Bool) {
        isCaptureSuspended = suspended
    }

    private func handle(type: CGEventType, event: CGEvent) {
        guard !isCaptureSuspended else { return }
        guard type == .keyDown || type == .keyUp || type == .flagsChanged else { return }
        onEventDebug?(HotKeyDefinition.describe(cgEvent: event, type: type))
        if type == .flagsChanged {
            handleFlagsChanged(event)
            return
        }
        guard let mode = mode(for: event, type: type) else { return }
        onEventDebug?("CGEventTap matched \(mode.rawValue): \(HotKeyDefinition.describe(cgEvent: event, type: type))")

        if hotkeyMode == .toggle {
            guard type == .keyDown,
                  event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else {
                return
            }
            if let activeMode {
                self.activeMode = nil
                onRelease?(activeMode)
            } else {
                activeMode = mode
                onPress?(mode)
            }
            return
        }

        if type == .keyDown,
           event.getIntegerValueField(.keyboardEventAutorepeat) == 0 {
            if activeMode == nil {
                activeMode = mode
                onPress?(mode)
            }
        } else if type == .keyUp {
            let releaseMode = activeMode ?? mode
            activeMode = nil
            onRelease?(releaseMode)
        }
    }

    private func handleFlagsChanged(_ event: CGEvent) {
        if let mode = mode(for: event, type: .flagsChanged) {
            onEventDebug?("CGEventTap matched \(mode.rawValue): \(HotKeyDefinition.describe(cgEvent: event, type: .flagsChanged))")
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
            return
        }

        guard hotkeyMode == .pressToTalk,
              let activeMode,
              hotkeyDefinition(for: activeMode).isModifierOnly else {
            return
        }
        self.activeMode = nil
        onRelease?(activeMode)
    }

    private func mode(for event: CGEvent, type: CGEventType) -> PipelineMode? {
        if dictationHotkey.matches(event, type: type) {
            return .dictation
        }
        if editSelectionHotkey.matches(event, type: type) {
            return .editSelection
        }
        return nil
    }

    private func hotkeyDefinition(for mode: PipelineMode) -> HotKeyDefinition {
        switch mode {
        case .dictation:
            return dictationHotkey
        case .editSelection:
            return editSelectionHotkey
        }
    }
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
