import SwiftUI

@main
struct ScrubApp: App {
    @State private var store = AppStore()
    @State private var auth = AuthStore()
    @State private var assistant = AssistantStore()
    @AppStorage(PreferenceKey.showMenuBarIcon) private var showMenuBarIcon = true

    init() {
        Preferences.registerDefaults()
    }

    private var isSignedIn: Bool {
        if case .signedIn = auth.state { return true }
        return false
    }

    var body: some Scene {
        // A single-state utility (like System Settings / Disk Utility), so a `Window`
        // rather than a document-style `WindowGroup` — one instance, no File ▸ New.
        Window("Scrub", id: ScrubWindow.main) {
            RootView(store: store)
                .environment(auth)
                .environment(assistant)
                .frame(minWidth: 820, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 640)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    Task { await store.loadApps() }
                }
                .keyboardShortcut("r", modifiers: .command)
                .disabled(!isSignedIn)
            }
        }

        Settings {
            SettingsView()
                .environment(auth)
                .environment(assistant)
        }

        MenuBarExtra("Scrub", image: "MenuBarIcon", isInserted: $showMenuBarIcon) {
            MenuBarContent(store: store, auth: auth)
        }
        .menuBarExtraStyle(.menu)
    }
}
