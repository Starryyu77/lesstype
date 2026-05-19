import AppKit
import ApplicationServices
import Foundation

final class SelectedTextReader {
    func readSelectedText() throws -> String {
        if let text = try? readViaAccessibility(), !text.isEmpty {
            return text
        }
        return try readViaClipboard()
    }

    private func readViaAccessibility() throws -> String {
        guard AXIsProcessTrusted() else {
            throw AppError.accessibilityPermissionDenied
        }
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        guard AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused) == .success,
              let element = focused else {
            throw AppError.selectedTextUnavailable
        }
        var selected: CFTypeRef?
        guard AXUIElementCopyAttributeValue((element as! AXUIElement), kAXSelectedTextAttribute as CFString, &selected) == .success else {
            throw AppError.selectedTextUnavailable
        }
        return selected as? String ?? ""
    }

    private func readViaClipboard() throws -> String {
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshotForSelection.capture(from: pasteboard)
        pasteboard.clearContents()
        guard postCommandC() else {
            snapshot.restore(to: pasteboard)
            throw AppError.selectedTextUnavailable
        }
        Thread.sleep(forTimeInterval: 0.12)
        let text = pasteboard.string(forType: .string) ?? ""
        snapshot.restore(to: pasteboard)
        guard !text.isEmpty else {
            throw AppError.selectedTextUnavailable
        }
        return text
    }

    private func postCommandC() -> Bool {
        let keyCodeForC: CGKeyCode = 8
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCodeForC, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCodeForC, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
    }
}

private struct ClipboardSnapshotForSelection {
    let items: [NSPasteboardItem]

    static func capture(from pasteboard: NSPasteboard) -> ClipboardSnapshotForSelection {
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
        return ClipboardSnapshotForSelection(items: copied)
    }

    func restore(to pasteboard: NSPasteboard) {
        pasteboard.clearContents()
        if !items.isEmpty {
            pasteboard.writeObjects(items)
        }
    }
}

