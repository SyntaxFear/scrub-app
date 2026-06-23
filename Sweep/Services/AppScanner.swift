import AppKit

/// Discovers installed applications. All work is synchronous file IO intended
/// to be run off the main actor.
enum AppScanner {

    /// Phase 1: enumerate `.app` bundles quickly (no size calculation).
    static func discover() -> [InstalledApp] {
        var seen = Set<String>()
        var apps: [InstalledApp] = []

        for dir in FileSystem.applicationDirectories {
            for url in FileSystem.children(of: dir) where url.pathExtension == "app" {
                guard let app = makeApp(from: url) else { continue }
                guard seen.insert(app.id).inserted else { continue }
                apps.append(app)
            }
        }

        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    /// Builds an `InstalledApp` from a single bundle URL, reading its identifier
    /// and version. Returns nil if the URL is not a readable app bundle.
    static func makeApp(from url: URL) -> InstalledApp? {
        guard let bundle = Bundle(url: url) else { return nil }

        let info = bundle.infoDictionary ?? [:]
        let bundleID = bundle.bundleIdentifier ?? ""
        let name = (info["CFBundleName"] as? String)
            ?? url.deletingPathExtension().lastPathComponent
        let version = (info["CFBundleShortVersionString"] as? String)
            ?? (info["CFBundleVersion"] as? String)
            ?? "—"

        let needsAdmin = !FileSystem.isUserDeletable(url)

        return InstalledApp(
            bundleID: bundleID,
            name: name,
            url: url,
            version: version,
            size: -1,
            bundleNeedsAdmin: needsAdmin
        )
    }

    /// Phase 2: compute the `.app` bundle size for one app.
    static func size(of app: InstalledApp) -> Int64 {
        FileSystem.size(of: app.url)
    }
}
