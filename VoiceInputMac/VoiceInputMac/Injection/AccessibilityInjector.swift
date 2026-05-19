import AppKit
import ApplicationServices
import Foundation

final class AccessibilityInjector: TextInjector {
    func insertText(_ text: String) async throws {
        guard AXIsProcessTrusted() else {
            throw AppError.accessibilityPermissionDenied
        }
        let element = try focusedElement()
        if AXUIElementSetAttributeValue(element, kAXSelectedTextAttribute as CFString, text as CFTypeRef) == .success {
            return
        }
        throw AppError.injectionFailed("Focused element does not accept AXSelectedText")
    }

    func replaceSelectedText(_ text: String) async throws {
        try await insertText(text)
    }

    private func focusedElement() throws -> AXUIElement {
        let system = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let status = AXUIElementCopyAttributeValue(system, kAXFocusedUIElementAttribute as CFString, &focused)
        guard status == .success, let element = focused else {
            throw AppError.injectionFailed("No focused accessibility element")
        }
        return element as! AXUIElement
    }
}

