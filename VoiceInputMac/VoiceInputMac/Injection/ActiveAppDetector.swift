import AppKit
import CoreGraphics
import Foundation

struct ActiveAppContext: Equatable {
    let activeApp: String
    let bundleIdentifier: String
    let windowTitle: String
    let processIdentifier: pid_t
}

final class ActiveAppDetector {
    func currentContext() -> ActiveAppContext {
        let app = NSWorkspace.shared.frontmostApplication
        let appName = app?.localizedName ?? "Unknown"
        let bundleID = app?.bundleIdentifier ?? ""
        return ActiveAppContext(
            activeApp: appName,
            bundleIdentifier: bundleID,
            windowTitle: windowTitle(for: app?.processIdentifier),
            processIdentifier: app?.processIdentifier ?? 0
        )
    }

    private func windowTitle(for pid: pid_t?) -> String {
        guard let pid else { return "" }
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return ""
        }
        for item in list {
            let ownerPID = item[kCGWindowOwnerPID as String] as? pid_t
            let layer = item[kCGWindowLayer as String] as? Int
            if ownerPID == pid, layer == 0 {
                return item[kCGWindowName as String] as? String ?? ""
            }
        }
        return ""
    }
}
