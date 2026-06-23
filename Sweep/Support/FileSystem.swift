import Foundation

/// Centralised knowledge about where macOS stores app-related files and how to
/// measure them. Pure, stateless helpers — safe to call from background tasks.
enum FileSystem {

    static let fm = FileManager.default

    // MARK: - Roots

    static var home: URL {
        URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
    }

    static var userLibrary: URL {
        home.appendingPathComponent("Library", isDirectory: true)
    }

    static let systemLibrary = URL(fileURLWithPath: "/Library", isDirectory: true)

    /// Directories searched for installed `.app` bundles.
    static var applicationDirectories: [URL] {
        [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            home.appendingPathComponent("Applications", isDirectory: true),
        ]
    }

    // MARK: - Existence

    static func exists(_ url: URL) -> Bool {
        fm.fileExists(atPath: url.path)
    }

    static func isDirectory(_ url: URL) -> Bool {
        var isDir: ObjCBool = false
        let ok = fm.fileExists(atPath: url.path, isDirectory: &isDir)
        return ok && isDir.boolValue
    }

    /// Lists the immediate children of a directory, returning `[]` on any error
    /// (e.g. permission denied without Full Disk Access).
    static func children(of url: URL) -> [URL] {
        (try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )) ?? []
    }

    // MARK: - Size

    /// Allocated size of a file or directory tree, in bytes. Returns 0 on error.
    static func size(of url: URL) -> Int64 {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey,
        ]

        // Single file fast path.
        if let values = try? url.resourceValues(forKeys: Set(keys)),
           values.isRegularFile == true {
            return Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return 0 }

        var total: Int64 = 0
        for case let child as URL in enumerator {
            guard let values = try? child.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            total += Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0)
        }
        return total
    }

    // MARK: - Writability

    /// True when the current user can delete the item directly (its parent
    /// directory is writable). Used to decide trash vs. privileged removal.
    static func isUserDeletable(_ url: URL) -> Bool {
        fm.isWritableFile(atPath: url.deletingLastPathComponent().path)
    }
}
