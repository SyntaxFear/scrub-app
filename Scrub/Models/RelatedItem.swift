import Foundation

/// A single file or folder associated with an app (or an orphaned leftover).
struct RelatedItem: Identifiable, Hashable, Sendable {
    let url: URL
    let category: ItemCategory
    let confidence: MatchConfidence
    let domain: FileDomain
    /// On-disk (allocated) size in bytes — what deleting actually frees. `-1` means
    /// "not computed yet".
    var size: Int64
    /// Apparent (logical) size in bytes — Finder's "Size". Larger than `size` for
    /// sparse files. `-1` means "not computed yet".
    var apparentSize: Int64 = -1
    /// True when the item was matched only by the developer's Team ID (e.g. a
    /// `Group Containers/<TeamID>.…` folder). Team IDs are shared across *all* of
    /// a vendor's apps, so such a folder may hold data for sibling apps too
    /// (Microsoft Office, Apple iWork, …). These are surfaced but never selected
    /// by default, so uninstalling one app can't silently break another.
    var vendorShared: Bool = false

    var id: URL { url }
    var displayName: String { url.lastPathComponent }
    var path: String { url.path }

    /// A friendlier path with the home directory collapsed to `~`.
    var abbreviatedPath: String {
        (url.path as NSString).abbreviatingWithTildeInPath
    }

    // Equality MUST include `size`: SwiftUI's Table diffs rows by element
    // equality, so if `==` ignored `size`, a row whose size changes from
    // "calculating" (-1) to its real value would be treated as unchanged and the
    // Size cell would never refresh. `url` alone identifies the item (see `id`).
    static func == (lhs: RelatedItem, rhs: RelatedItem) -> Bool {
        lhs.url == rhs.url && lhs.size == rhs.size && lhs.apparentSize == rhs.apparentSize
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(size)
        hasher.combine(apparentSize)
    }
}
