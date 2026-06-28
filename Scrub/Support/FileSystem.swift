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

    /// On-disk (allocated) and apparent (logical) size of a file or directory tree,
    /// in bytes, computed in a single walk. The two differ for **sparse files** —
    /// e.g. virtual-machine disk images — where the apparent size can be far larger
    /// than the blocks actually used on disk. On-disk is what you truly reclaim by
    /// deleting; apparent is what Finder's "Size" column reports. Returns (0, 0) on
    /// error.
    static func measure(of url: URL) -> (onDisk: Int64, apparent: Int64) {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .totalFileAllocatedSizeKey, .fileAllocatedSizeKey, .fileSizeKey,
        ]

        func sizes(_ values: URLResourceValues) -> (Int64, Int64) {
            (Int64(values.totalFileAllocatedSize ?? values.fileAllocatedSize ?? 0),
             Int64(values.fileSize ?? 0))
        }

        // Single file fast path.
        if let values = try? url.resourceValues(forKeys: Set(keys)),
           values.isRegularFile == true {
            return sizes(values)
        }

        guard let enumerator = fm.enumerator(
            at: url,
            includingPropertiesForKeys: keys,
            options: [],
            errorHandler: { _, _ in true }
        ) else { return (0, 0) }

        var onDisk: Int64 = 0
        var apparent: Int64 = 0
        for case let child as URL in enumerator {
            guard let values = try? child.resourceValues(forKeys: Set(keys)),
                  values.isRegularFile == true else { continue }
            let (d, a) = sizes(values)
            onDisk += d
            apparent += a
        }
        return (onDisk, apparent)
    }

    /// On-disk (allocated) size only — the space actually freed by deleting. Returns
    /// 0 on error.
    static func size(of url: URL) -> Int64 {
        measure(of: url).onDisk
    }

    // MARK: - Writability

    /// True when the current user can delete the item directly by moving it to
    /// the Trash. Both the parent directory *and* the item itself must be
    /// writable by us. The item check matters for root-owned apps (e.g. App
    /// Store installs) sitting in the admin-writable `/Applications` folder:
    /// the parent is writable, but the bundle is not, so `trashItem` would fail.
    /// Those are reported as not user-deletable and routed to the privileged
    /// removal path instead. Used to decide trash vs. privileged removal.
    static func isUserDeletable(_ url: URL) -> Bool {
        let parent = url.deletingLastPathComponent().path
        return fm.isWritableFile(atPath: parent) && fm.isWritableFile(atPath: url.path)
    }
}
