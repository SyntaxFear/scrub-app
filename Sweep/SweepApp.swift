import SwiftUI

@main
struct ScrubApp: App {
    @State private var store = AppStore()
    @State private var auth = AuthStore()
    @AppStorage(PreferenceKey.showMenuBarIcon) private var showMenuBarIcon = true

    init() {
        Preferences.registerDefaults()
    }

    private var isSignedIn: Bool {
        if case .signedIn = auth.state { return true }
        return false
    }

    var body: some Scene {
        WindowGroup(id: ScrubWindow.main) {
            RootView(store: store)
                .environment(auth)
                .frame(minWidth: 820, minHeight: 520)
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 640)
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
        }

        MenuBarExtra("Scrub", systemImage: "sparkles", isInserted: $showMenuBarIcon) {
            MenuBarContent(store: store, auth: auth)
        }
        .menuBarExtraStyle(.menu)
    }
}
