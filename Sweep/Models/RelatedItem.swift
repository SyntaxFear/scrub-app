import Foundation

/// A single file or folder associated with an app (or an orphaned leftover).
struct RelatedItem: Identifiable, Hashable, Sendable {
    let url: URL
    let category: ItemCategory
    let confidence: MatchConfidence
    let domain: FileDomain
    /// Size in bytes. `-1` means "not computed yet".
    var size: Int64

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
        lhs.url == rhs.url && lhs.size == rhs.size
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(url)
        hasher.combine(size)
    }
}
