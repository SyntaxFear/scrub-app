import SwiftUI
import AppKit

/// The menu shown from Scrub's optional menu bar icon. Lightweight quick actions;
/// the heavy lifting stays in the main window.
struct MenuBarContent: View {
    let store: AppStore
    let auth: AuthStore
    @Environment(\.openWindow) private var openWindow

    private var isSignedIn: Bool {
        if case .signedIn = auth.state { return true }
        return false
    }

    var body: some View {
        Button { showMainWindow() } label: {
            Label("Open Scrub", systemImage: "macwindow")
        }

        // Scanning and emptying the Trash are gated behind sign-in, like the main
        // window — the menu bar must not be a back door around the required wall.
        if isSignedIn {
            Button {
                showMainWindow()
                Task { await store.loadApps() }
            } label: {
                Label("Scan for Apps", systemImage: "magnifyingglass")
            }
            Divider()
            Button(role: .destructive) { confirmEmptyTrash() } label: {
                Label("Empty Trash…", systemImage: "trash")
            }
        }

        Button { UpdaterService.shared.checkForUpdates() } label: {
            Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
        }

        Divider()

        SettingsLink { Label("Settings…", systemImage: "gearshape") }
        Button { NSApp.terminate(nil) } label: {
            Label("Quit Scrub", systemImage: "power")
        }
        .keyboardShortcut("q")
    }

    private func showMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        openWindow(id: ScrubWindow.main)
    }

    private func confirmEmptyTrash() {
        let count = TrashService.itemCount()
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        if count == 0 {
            alert.messageText = "The Trash is empty"
            alert.informativeText = "There’s nothing to empty right now."
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        alert.messageText = "Empty the Trash?"
        alert.informativeText =
            "\(count) item\(count == 1 ? "" : "s") will be permanently deleted. This can’t be undone."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Empty Trash")
        alert.addButton(withTitle: "Cancel")
        if alert.runModal() == .alertFirstButtonReturn {
            TrashService.empty()
        }
    }
}

/// Stable window identifiers used with `openWindow`.
enum ScrubWindow {
    static let main = "main"
}
