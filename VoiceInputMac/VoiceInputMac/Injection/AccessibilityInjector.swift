import AppKit
import ApplicationServices
import Foundation

final class AccessibilityInjector: TextInjector {
    func insertText(_ text: String) async throws {
        try await writeText(text, requireSelection: false)
    }

    func replaceSelectedText(_ text: String) async throws {
        try await writeText(text, requireSelection: true)
    }

    func cleanFocusedText(_ cleaner: (String) -> String) {
        guard AccessibilityPermission.isTrusted(prompt: false),
              let element = try? focusedElement(),
              let currentValue = stringAttribute(kAXValueAttribute, from: element) else {
            return
        }

        let cleanedValue = cleaner(currentValue)
        guard cleanedValue != currentValue else {
            return
        }

        let selectedRange = selectedTextRange(from: element) ?? CFRange(location: cleanedValue.utf16.count, length: 0)
        guard AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, cleanedValue as CFTypeRef) == .success else {
            return
        }

        var caretRange = CFRange(
            location: min(selectedRange.location, cleanedValue.utf16.count),
            length: 0
        )
        if let caretValue = AXValueCreate(.cfRange, &caretRange) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue)
        }
    }

    private func writeText(_ text: String, requireSelection: Bool) async throws {
        guard AccessibilityPermission.isTrusted(prompt: true) else {
            throw AppError.accessibilityPermissionDenied
        }

        var lastError: Error?
        for _ in 0..<6 {
            do {
                let element = try focusedElement()
                if replaceValueUsingSelectedRange(in: element, with: text, requireSelection: requireSelection) {
                    return
                }
                throw AppError.injectionFailed("Focused element does not accept AX text insertion")
            } catch {
                lastError = error
                try? await Task.sleep(nanoseconds: 80_000_000)
            }
        }

        throw lastError ?? AppError.injectionFailed("No focused accessibility element")
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

    private func replaceValueUsingSelectedRange(
        in element: AXUIElement,
        with text: String,
        requireSelection: Bool
    ) -> Bool {
        guard let currentValue = stringAttribute(kAXValueAttribute, from: element),
              let selectedRange = selectedTextRange(from: element),
              !requireSelection || selectedRange.length > 0,
              let newValue = AXTextRangeReplacement.replacing(currentValue, range: selectedRange, with: text) else {
            return false
        }

        guard AXUIElementSetAttributeValue(element, kAXValueAttribute as CFString, newValue as CFTypeRef) == .success else {
            return false
        }

        var caretRange = CFRange(location: selectedRange.location + text.utf16.count, length: 0)
        if let caretValue = AXValueCreate(.cfRange, &caretRange) {
            AXUIElementSetAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, caretValue)
        }
        return true
    }

    private func stringAttribute(_ attribute: String, from element: AXUIElement) -> String? {
        var valueRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, attribute as CFString, &valueRef) == .success else {
            return nil
        }
        return valueRef as? String
    }

    private func selectedTextRange(from element: AXUIElement) -> CFRange? {
        var rangeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, kAXSelectedTextRangeAttribute as CFString, &rangeRef) == .success,
              let rangeRef else {
            return nil
        }
        let rangeValue = rangeRef as! AXValue
        guard
              AXValueGetType(rangeValue) == .cfRange else {
            return nil
        }
        var range = CFRange()
        guard AXValueGetValue(rangeValue, .cfRange, &range) else {
            return nil
        }
        return range
    }
}

struct AXTextRangeReplacement {
    static func replacing(_ value: String, range: CFRange, with replacement: String) -> String? {
        guard range.location >= 0, range.length >= 0 else {
            return nil
        }
        let utf16Count = value.utf16.count
        guard range.location <= utf16Count,
              range.length <= utf16Count - range.location,
              let startUTF16 = value.utf16.index(value.utf16.startIndex, offsetBy: range.location, limitedBy: value.utf16.endIndex),
              let endUTF16 = value.utf16.index(startUTF16, offsetBy: range.length, limitedBy: value.utf16.endIndex),
              let start = String.Index(startUTF16, within: value),
              let end = String.Index(endUTF16, within: value) else {
            return nil
        }

        var result = value
        result.replaceSubrange(start..<end, with: replacement)
        return result
    }
}
