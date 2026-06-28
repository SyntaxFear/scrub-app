import Foundation

/// Given one installed app, finds every related support file across the standard
/// macOS storage locations. Matches by bundle identifier (`.exact`) and, for
/// folders that are named after the app or its developer rather than its
/// identifier, by display name or Team ID (`.likely`).
enum LeftoverScanner {

    /// Returns the app's own bundle plus all discovered support files, sorted
    /// for display.
    static func scan(app: InstalledApp) -> [RelatedItem] {
        var items: [RelatedItem] = []

        // The application bundle itself.
        items.append(RelatedItem(
            url: app.url,
            category: .application,
            confidence: .exact,
            domain: app.bundleNeedsAdmin ? .admin : .user,
            size: -1
        ))

        let bundleID = app.bundleID.isEmpty ? nil : app.bundleID
        let name = app.name
        // The developer Team ID keys Group Containers and some App Scripts that
        // are not named after the bundle ID.
        let teamID = CodeSignature.teamIdentifier(forBundleAt: app.url)

        items.append(contentsOf: userLibraryItems(bundleID: bundleID, name: name, teamID: teamID))
        items.append(contentsOf: systemLibraryItems(bundleID: bundleID))
        items.append(contentsOf: launchItems(bundleID: bundleID, name: name))

        return dedupe(items).sorted(by: ordering)
    }

    // MARK: - User library (~/Library)

    private static func userLibraryItems(bundleID: String?, name: String, teamID: String?) -> [RelatedItem] {
        let lib = FileSystem.userLibrary
        var out: [RelatedItem] = []

        // bundleID-keyed exact matches: <root>/<bundleID>[.ext]
        if let id = bundleID {
            out += exactChild(lib, "Containers/\(id)", .containers)
            out += exactChild(lib, "Application Scripts/\(id)", .applicationScripts)
            out += exactChild(lib, "Saved Application State/\(id).savedState", .savedState)
            out += exactChild(lib, "HTTPStorages/\(id)", .httpStorages)
            out += exactChild(lib, "HTTPStorages/\(id).binarycookies", .cookies)
            out += exactChild(lib, "WebKit/\(id)", .webKit)
            out += exactChild(lib, "Caches/\(id)", .caches)
            out += exactChild(lib, "Application Support/\(id)", .applicationSupport)
            out += exactChild(lib, "Logs/\(id)", .logs)

            // Preferences: any plist whose name starts with the bundle ID, both
            // the top-level folder and the per-host ByHost folder.
            out += prefixMatches(in: lib.appendingPathComponent("Preferences"),
                                 prefix: id, category: .preferences, confidence: .exact)
            out += prefixMatches(in: lib.appendingPathComponent("Preferences/ByHost"),
                                 prefix: id, category: .preferences, confidence: .exact)

            // Cookies keyed by bundle ID.
            out += exactChild(lib, "Cookies/\(id).binarycookies", .cookies)

            // Group containers contain the bundle ID as a substring.
            out += substringMatches(in: lib.appendingPathComponent("Group Containers"),
                                    needle: id, category: .groupContainers)
        }

        // Team-ID-keyed matches: Group Containers and App Scripts are frequently
        // prefixed with the 10-character team ID rather than the bundle ID. A
        // team ID is shared by every app from the same developer, so these are
        // flagged `vendorShared` — surfaced for review but never auto-selected.
        if let team = teamID {
            out += substringMatches(in: lib.appendingPathComponent("Group Containers"),
                                    needle: team, category: .groupContainers, vendorShared: true)
            out += substringMatches(in: lib.appendingPathComponent("Application Scripts"),
                                    needle: team, category: .applicationScripts, vendorShared: true)
        }

        // Name-keyed likely matches: folders named after the app's display name.
        for sub in ["Application Support", "Caches", "Logs"] {
            out += likelyChild(lib, "\(sub)/\(name)", category(forSub: sub))
        }

        return out
    }

    // MARK: - System library (/Library, admin domain)

    /// App leftovers that live in the system-wide `/Library`. These require an
    /// administrator password to remove, so they are tagged `.admin`. Only exact,
    /// bundle-ID-named items are matched here to keep false positives at zero.
    private static func systemLibraryItems(bundleID: String?) -> [RelatedItem] {
        guard let id = bundleID else { return [] }
        let lib = FileSystem.systemLibrary
        var out: [RelatedItem] = []

        out += exactChild(lib, "Application Support/\(id)", .applicationSupport, domain: .admin)
        out += exactChild(lib, "Caches/\(id)", .caches, domain: .admin)
        out += exactChild(lib, "Logs/\(id)", .logs, domain: .admin)
        out += exactChild(lib, "PrivilegedHelperTools/\(id)", .binarySupport, domain: .admin)

        // System preferences: plists named after the bundle ID.
        out += prefixMatches(in: lib.appendingPathComponent("Preferences"),
                             prefix: id, category: .preferences, confidence: .exact, domain: .admin)

        return out
    }

    private static func category(forSub sub: String) -> ItemCategory {
        switch sub {
        case "Application Support": return .applicationSupport
        case "Caches":              return .caches
        case "Logs":                return .logs
        default:                    return .other
        }
    }

    // MARK: - Launch agents & daemons

    private static func launchItems(bundleID: String?, name: String) -> [RelatedItem] {
        var out: [RelatedItem] = []
        let locations: [(URL, ItemCategory, FileDomain)] = [
            (FileSystem.userLibrary.appendingPathComponent("LaunchAgents"), .launchAgent, .user),
            (FileSystem.systemLibrary.appendingPathComponent("LaunchAgents"), .launchAgent, .admin),
            (FileSystem.systemLibrary.appendingPathComponent("LaunchDaemons"), .launchDaemon, .admin),
        ]

        for (dir, category, domain) in locations {
            for plist in FileSystem.children(of: dir) where plist.pathExtension == "plist" {
                guard launchPlist(plist, matches: bundleID, name: name) else { continue }
                out.append(RelatedItem(
                    url: plist,
                    category: category,
                    confidence: bundleID != nil ? .exact : .likely,
                    domain: domain,
                    size: -1
                ))
            }
        }
        return out
    }

    /// A launch plist matches if its filename, Label, or executable path
    /// references the bundle ID, or its filename references the app name.
    private static func launchPlist(_ url: URL, matches bundleID: String?, name: String) -> Bool {
        let filename = url.deletingPathExtension().lastPathComponent.lowercased()

        if let id = bundleID?.lowercased(), filename.contains(id) { return true }

        if let data = try? Data(contentsOf: url),
           let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
           let dict = plist as? [String: Any] {
            let label = (dict["Label"] as? String ?? "").lowercased()
            let program = (dict["Program"] as? String ?? "").lowercased()
            let args = (dict["ProgramArguments"] as? [String])?.joined(separator: " ").lowercased() ?? ""
            if let id = bundleID?.lowercased(),
               label.contains(id) || program.contains(id) || args.contains(id) {
                return true
            }
        }

        // Name-only fallback, but only for distinctive names to limit false hits.
        let needle = name.lowercased().replacingOccurrences(of: " ", with: "")
        return needle.count >= 4 && filename.replacingOccurrences(of: " ", with: "").contains(needle)
    }

    // MARK: - Match helpers

    private static func exactChild(_ root: URL, _ relative: String, _ category: ItemCategory,
                                   domain: FileDomain = .user) -> [RelatedItem] {
        let url = root.appendingPathComponent(relative)
        guard FileSystem.exists(url) else { return [] }
        return [RelatedItem(url: url, category: category, confidence: .exact,
                            domain: domain, size: -1)]
    }

    private static func likelyChild(_ root: URL, _ relative: String, _ category: ItemCategory,
                                    domain: FileDomain = .user) -> [RelatedItem] {
        let url = root.appendingPathComponent(relative)
        guard FileSystem.exists(url) else { return [] }
        return [RelatedItem(url: url, category: category, confidence: .likely,
                            domain: domain, size: -1)]
    }

    private static func prefixMatches(in dir: URL, prefix: String,
                                      category: ItemCategory,
                                      confidence: MatchConfidence,
                                      domain: FileDomain = .user) -> [RelatedItem] {
        FileSystem.children(of: dir)
            .filter { $0.lastPathComponent.hasPrefix(prefix) }
            .map { RelatedItem(url: $0, category: category, confidence: confidence,
                               domain: domain, size: -1) }
    }

    private static func substringMatches(in dir: URL, needle: String,
                                         category: ItemCategory,
                                         domain: FileDomain = .user,
                                         vendorShared: Bool = false) -> [RelatedItem] {
        FileSystem.children(of: dir)
            .filter { $0.lastPathComponent.localizedCaseInsensitiveContains(needle) }
            .map { RelatedItem(url: $0, category: category, confidence: .likely,
                               domain: domain, size: -1, vendorShared: vendorShared) }
    }

    // MARK: - Ordering & dedupe

    static func ordering(_ a: RelatedItem, _ b: RelatedItem) -> Bool {
        if a.category.sortOrder != b.category.sortOrder {
            return a.category.sortOrder < b.category.sortOrder
        }
        return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
    }

    static func dedupe(_ items: [RelatedItem]) -> [RelatedItem] {
        var seen = Set<URL>()
        return items.filter { seen.insert($0.url.standardizedFileURL).inserted }
    }
}
