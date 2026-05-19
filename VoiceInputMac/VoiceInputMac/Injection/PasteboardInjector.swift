import AppKit
import ApplicationServices
import Foundation

final class PasteboardInjector: TextInjector {
    private let restoreClipboard: () -> Bool

    init(restoreClipboard: @escaping () -> Bool) {
        self.restoreClipboard = restoreClipboard
    }

    func insertText(_ text: String) async throws {
        try await paste(text)
    }

    func replaceSelectedText(_ text: String) async throws {
        try await paste(text)
    }

    private func paste(_ text: String) async throws {
        guard AccessibilityPermission.isTrusted(prompt: true) else {
            throw AppError.accessibilityPermissionDenied
        }
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard performMenuPaste() || postCommandV() else {
            if restoreClipboard() {
                snapshot.restore(to: pasteboard)
            }
            throw AppError.injectionFailed("Unable to trigger Paste")
        }

        try await Task.sleep(nanoseconds: 1_500_000_000)
        if restoreClipboard() {
            snapshot.restore(to: pasteboard)
        }
    }

    private func postCommandV() -> Bool {
        let keyCodeForV: CGKeyCode = 9
        let source = CGEventSource(stateID: .hidSystemState)
        guard let down = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: true),
              let up = CGEvent(keyboardEventSource: source, virtualKey: keyCodeForV, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        usleep(20_000)
        up.post(tap: .cghidEventTap)
        return true
    }

    private func performMenuPaste() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        var menuBarRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(appElement, kAXMenuBarAttribute as CFString, &menuBarRef) == .success,
              let menuBar = menuBarRef else {
            return false
        }
        let menuBarElement = menuBar as! AXUIElement
        let pasteItem = findPasteMenuItem(in: menuBarElement) ?? findPasteMenuItemAfterOpeningEditMenu(in: menuBarElement)
        guard let pasteItem else {
            return false
        }
        return AXUIElementPerformAction(pasteItem, kAXPressAction as CFString) == .success
    }

    private func findPasteMenuItemAfterOpeningEditMenu(in menuBar: AXUIElement) -> AXUIElement? {
        guard let editMenu = findEditMenu(in: menuBar),
              AXUIElementPerformAction(editMenu, kAXPressAction as CFString) == .success else {
            return nil
        }
        usleep(80_000)
        return findPasteMenuItem(in: editMenu) ?? findPasteMenuItem(in: menuBar)
    }

    private func findEditMenu(in element: AXUIElement) -> AXUIElement? {
        if isEditMenu(element) {
            return element
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        for child in children {
            if let match = findEditMenu(in: child) {
                return match
            }
        }
        return nil
    }

    private func isEditMenu(_ element: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String,
              role == kAXMenuBarItemRole else {
            return false
        }
        let title = stringAttribute(kAXTitleAttribute, from: element)
        return title == "Edit" || title == "编辑" || title == "編輯"
    }

    private func findPasteMenuItem(in element: AXUIElement) -> AXUIElement? {
        if isPasteMenuItem(element) {
            return element
        }

        var childrenRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXChildrenAttribute as CFString, &childrenRef) == .success,
              let children = childrenRef as? [AXUIElement] else {
            return nil
        }
        for child in children {
            if let match = findPasteMenuItem(in: child) {
                return match
            }
        }
        return nil
    }

    private func isPasteMenuItem(_ element: AXUIElement) -> Bool {
        var roleRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXRoleAttribute as CFString, &roleRef) == .success,
              let role = roleRef as? String,
              role == kAXMenuItemRole else {
            return false
        }

        let title = stringAttribute(kAXTitleAttribute, from: element)
        if isPlainPasteTitle(title) {
            return true
        }

        let command = stringAttribute(kAXMenuItemCmdCharAttribute, from: element).lowercased()
        let modifiers = intAttribute(kAXMenuItemCmdModifiersAttribute, from: element)
        return command == "v" && modifiers == 0 && !title.localizedCaseInsensitiveContains("style")
    }

    private func isPlainPasteTitle(_ title: String) -> Bool {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == "Paste" || trimmed == "粘贴" || trimmed == "貼上"
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success else {
            return ""
        }
        return valueRef as? String ?? ""
    }

    private func intAttribute(_ attribute: String, from element: AXUIElement) -> Int {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success else {
            return 0
        }
        return valueRef as? Int ?? 0
    }
}

struct ClipboardSnapshot {
    let items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard) -> ClipboardSnapshot {
        let copied = pasteboard.pasteboardItems?.map { item -> NSPasteboardItem in
            let clone = NSPasteboardItem()
            for type in item.types {
                if let data = item.data(forType: type) {
                    clone.setData(data, forType: type)
                } else if let string = item.string(forType: type) {
                    clone.setString(string, forType: type)
                }
            }
            return clone
        } ?? []
        return ClipboardSnapshot(items: copied)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}
