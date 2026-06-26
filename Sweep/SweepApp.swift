import SwiftUI

@main
struct ScrubApp: App {
    @State private var store = AppStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .frame(minWidth: 820, minHeight: 520)
                .onAppear { store.start() }
        }
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1000, height: 640)
        .commands {
            CommandGroup(after: .toolbar) {
                Button("Refresh") {
                    Task { await store.loadApps() }
                }
                .keyboardShortcut("r", modifiers: .command)
            }
        }
    }
}
