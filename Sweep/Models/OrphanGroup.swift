import Foundation

/// A cluster of leftover files that appear to belong to one app which is no
/// longer installed, keyed by a best-guess bundle identifier.
struct OrphanGroup: Identifiable, Hashable, Sendable {
    let inferredBundleID: String
    let displayName: String
    var items: [RelatedItem]

    var id: String { inferredBundleID }
    var totalSize: Int64 { items.reduce(0) { $0 + max(0, $1.size) } }

    static func == (lhs: OrphanGroup, rhs: OrphanGroup) -> Bool {
        lhs.inferredBundleID == rhs.inferredBundleID
    }
    func hash(into hasher: inout Hasher) { hasher.combine(inferredBundleID) }
}
