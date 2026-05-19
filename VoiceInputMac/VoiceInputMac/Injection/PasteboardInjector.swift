import AppKit
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
        let pasteboard = NSPasteboard.general
        let snapshot = ClipboardSnapshot.capture(from: pasteboard)
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard postCommandV() else {
            if restoreClipboard() {
                snapshot.restore(to: pasteboard)
            }
            throw AppError.injectionFailed("Unable to post Cmd+V event")
        }

        try await Task.sleep(nanoseconds: 300_000_000)
        if restoreClipboard() {
            snapshot.restore(to: pasteboard)
        }
    }

    private func postCommandV() -> Bool {
        let keyCodeForV: CGKeyCode = 9
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: keyCodeForV, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: keyCodeForV, keyDown: false) else {
            return false
        }
        down.flags = .maskCommand
        up.flags = .maskCommand
        down.post(tap: .cghidEventTap)
        up.post(tap: .cghidEventTap)
        return true
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
