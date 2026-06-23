import Foundation

/// Finds leftover files that look like they belong to apps which are no longer
/// installed. Works by collecting bundle-identifier-keyed entries across the
/// standard locations and subtracting the set of installed apps. Apple's own
/// files are excluded to avoid touching system data.
enum OrphanScanner {

    /// Locations whose immediate children are named by bundle identifier.
    private static func bundleKeyedLocations() -> [(URL, ItemCategory)] {
        let lib = FileSystem.userLibrary
        return [
            (lib.appendingPathComponent("Containers"), .containers),
            (lib.appendingPathComponent("Application Scripts"), .applicationScripts),
            (lib.appendingPathComponent("HTTPStorages"), .httpStorages),
            (lib.appendingPathComponent("WebKit"), .webKit),
            (lib.appendingPathComponent("Caches"), .caches),
        ]
    }

    static func scan(installed: [InstalledApp]) -> [OrphanGroup] {
        let installedIDs = Set(installed.map { $0.bundleID.lowercased() }.filter { !$0.isEmpty })
        var groups: [String: OrphanGroup] = [:]

        func consider(_ url: URL, id rawID: String, category: ItemCategory) {
            let id = rawID.lowercased()
            guard looksLikeBundleID(id),
                  !id.hasPrefix("com.apple."),
                  !installedIDs.contains(id) else { return }

            let item = RelatedItem(url: url, category: category, confidence: .likely,
                                   domain: .user, size: -1)
            if groups[id] != nil {
                groups[id]?.items.append(item)
            } else {
                groups[id] = OrphanGroup(
                    inferredBundleID: rawID,
                    displayName: friendlyName(from: rawID),
                    items: [item]
                )
            }
        }

        // Folders keyed directly by bundle identifier.
        for (dir, category) in bundleKeyedLocations() {
            for child in FileSystem.children(of: dir) {
                let id = child.pathExtension == "savedState"
                    ? child.deletingPathExtension().lastPathComponent
                    : child.lastPathComponent
                consider(child, id: id, category: category)
            }
        }

        // Preference plists: <bundleID>.plist
        let prefs = FileSystem.userLibrary.appendingPathComponent("Preferences")
        for child in FileSystem.children(of: prefs) where child.pathExtension == "plist" {
            consider(child, id: child.deletingPathExtension().lastPathComponent, category: .preferences)
        }

        // Saved application state: <bundleID>.savedState
        let saved = FileSystem.userLibrary.appendingPathComponent("Saved Application State")
        for child in FileSystem.children(of: saved) where child.pathExtension == "savedState" {
            consider(child, id: child.deletingPathExtension().lastPathComponent, category: .savedState)
        }

        return groups.values
            .sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
    }

    /// Heuristic: a reverse-DNS-ish identifier with at least two dotted parts.
    private static func looksLikeBundleID(_ s: String) -> Bool {
        let parts = s.split(separator: ".")
        guard parts.count >= 2 else { return false }
        let allowed = CharacterSet(charactersIn:
            "abcdefghijklmnopqrstuvwxyz0123456789.-_")
        return s.unicodeScalars.allSatisfy { allowed.contains($0) }
    }

    /// Turns `com.tinyspeck.slackmacgap` into a readable `Slackmacgap`.
    private static func friendlyName(from bundleID: String) -> String {
        let last = bundleID.split(separator: ".").last.map(String.init) ?? bundleID
        return last.isEmpty ? bundleID : last.prefix(1).uppercased() + last.dropFirst()
    }
}
