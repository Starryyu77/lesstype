import AppKit
import SwiftUI

@MainActor
final class SettingsWindowPresenter {
    static let shared = SettingsWindowPresenter()
    private var window: NSWindow?

    func show(appState: AppState) {
        let hosting = NSHostingView(rootView: SettingsView(appState: appState))
        if window == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 980, height: 680),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Lesstype Settings"
            window.titlebarAppearsTransparent = false
            window.isReleasedWhenClosed = false
            self.window = window
        }
        window?.contentView = hosting
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }
}
