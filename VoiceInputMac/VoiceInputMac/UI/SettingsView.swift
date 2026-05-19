import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState: AppState

    var body: some View {
        TabView {
            GeneralSettingsView(appState: appState)
                .tabItem { Label("General", systemImage: "gearshape") }
            ASRSettingsView(appState: appState)
                .tabItem { Label("ASR", systemImage: "waveform") }
            LLMSettingsView(appState: appState)
                .tabItem { Label("LLM", systemImage: "sparkles") }
            HotkeySettingsView(appState: appState)
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
            DictionaryView(appState: appState)
                .tabItem { Label("Dictionary", systemImage: "book") }
            HistoryView(appState: appState)
                .tabItem { Label("History", systemImage: "clock") }
            StyleProfilesView(appState: appState)
                .tabItem { Label("Styles", systemImage: "paintpalette") }
            PermissionGuideView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
        }
        .padding()
        .frame(width: 820, height: 560)
    }
}

