import Foundation

/// An application discovered on disk.
struct InstalledApp: Identifiable, Hashable, Sendable {
    let bundleID: String
    let name: String
    let url: URL
    let version: String
    /// Size of the `.app` bundle in bytes. `-1` means "not computed yet".
    var size: Int64
    /// True when the app's own bundle lives in a system-owned location and the
    /// `.app` itself needs admin rights to delete (e.g. `/Applications` items
    /// installed by a pkg as root). The associated user files are still trashed.
    let bundleNeedsAdmin: Bool

    var id: String { bundleID.isEmpty ? url.path : bundleID }

    static func == (lhs: InstalledApp, rhs: InstalledApp) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
