import ApplicationServices
import Foundation

final class CGEventTyper {
    func type(_ text: String) throws {
        guard AXIsProcessTrusted() else {
            throw AppError.accessibilityPermissionDenied
        }
        for scalar in text.unicodeScalars {
            var chars = [UniChar(scalar.value)]
            guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
                  let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
                throw AppError.injectionFailed("Unable to create keyboard event")
            }
            down.keyboardSetUnicodeString(stringLength: 1, unicodeString: &chars)
            up.keyboardSetUnicodeString(stringLength: 1, unicodeString: &chars)
            down.post(tap: .cghidEventTap)
            up.post(tap: .cghidEventTap)
        }
    }
}
