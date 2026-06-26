import AppKit

/// Thin wrapper over the Finder integration points we use.
enum Finder {

    /// Reveals an item in Finder, selecting it inside its containing folder —
    /// i.e. opens the exact folder where the data lives, with the item highlighted.
    @MainActor
    static func reveal(_ url: URL) {
        NSWorkspace.shared.activateFileViewerSelecting([url])
    }

    /// Opens the item itself (a folder opens in Finder; a file opens in its
    /// default app).
    @MainActor
    static func open(_ url: URL) {
        NSWorkspace.shared.open(url)
    }
}
