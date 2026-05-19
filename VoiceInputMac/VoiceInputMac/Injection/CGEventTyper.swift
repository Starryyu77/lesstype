import ApplicationServices
import Foundation

final class CGEventTyper {
    func type(_ text: String) throws {
        guard AXIsProcessTrusted() else {
            throw AppError.accessibilityPermissionDenied
        }
        let units = Array(text.utf16)
        guard !units.isEmpty else { return }

        let chunkSize = 64
        var offset = 0
        while offset < units.count {
            let end = min(offset + chunkSize, units.count)
            var chunk = Array(units[offset..<end])
            try postUnicodeChunk(&chunk)
            offset = end
            usleep(5_000)
        }
    }

    private func postUnicodeChunk(_ units: inout [UniChar]) throws {
        guard let down = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: true),
              let up = CGEvent(keyboardEventSource: nil, virtualKey: 0, keyDown: false) else {
            throw AppError.injectionFailed("Unable to create keyboard event")
        }
        units.withUnsafeBufferPointer { buffer in
            down.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
            up.keyboardSetUnicodeString(stringLength: buffer.count, unicodeString: buffer.baseAddress)
        }
        down.post(tap: .cghidEventTap)
        usleep(2_000)
        up.post(tap: .cghidEventTap)
    }
}
