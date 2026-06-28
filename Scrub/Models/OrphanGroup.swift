import Foundation

/// A cluster of leftover files that appear to belong to one app which is no
/// longer installed, keyed by a best-guess bundle identifier.
struct OrphanGroup: Identifiable, Hashable, Sendable {
    let inferredBundleID: String
    let displayName: String
    var items: [RelatedItem]

    var id: String { inferredBundleID }
    var totalSize: Int64 { items.reduce(0) { $0 + max(0, $1.size) } }

    // Equality includes `items` so a group whose leftover sizes change from
    // "calculating" (-1) to real values is re-rendered by SwiftUI; `id` (the bundle
    // ID) still gives the list a stable identity.
    static func == (lhs: OrphanGroup, rhs: OrphanGroup) -> Bool {
        lhs.inferredBundleID == rhs.inferredBundleID && lhs.items == rhs.items
    }
    func hash(into hasher: inout Hasher) {
        hasher.combine(inferredBundleID)
        hasher.combine(items)
    }
}
