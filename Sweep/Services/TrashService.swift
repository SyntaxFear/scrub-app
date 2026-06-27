import Foundation

/// Reads and empties the user's Trash (`~/.Trash`). Emptying is permanent and
/// irreversible, so callers must confirm with the user first.
enum TrashService {

    private static var trashURL: URL {
        FileSystem.home.appendingPathComponent(".Trash", isDirectory: true)
    }

    /// Top-level visible items in the Trash — matches what Finder shows.
    static func itemCount() -> Int {
        (try? FileSystem.fm.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ))?.count ?? 0
    }

    /// Permanently removes everything in the Trash, including hidden items.
    /// Returns false if any item could not be removed. Destructive — confirm first.
    @discardableResult
    static func empty() -> Bool {
        let contents = (try? FileSystem.fm.contentsOfDirectory(
            at: trashURL,
            includingPropertiesForKeys: nil,
            options: []
        )) ?? []
        var ok = true
        for item in contents {
            do {
                try FileSystem.fm.removeItem(at: item)
            } catch {
                ok = false
                NSLog("TrashService: could not remove \(item.lastPathComponent): \(error.localizedDescription)")
            }
        }
        return ok
    }
}
