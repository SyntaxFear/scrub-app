import Foundation

/// Last line of defence before anything is deleted. Every path must pass these
/// checks or removal is refused — protects against a heuristic ever producing a
/// dangerous path like `/`, `~`, or a top-level Library folder.
enum SafetyGuard {

    /// Paths that must never be deleted, even if a scanner somehow proposes them.
    private static var forbiddenExact: Set<String> {
        var set: Set<String> = [
            "/", "/System", "/usr", "/bin", "/sbin", "/etc", "/var", "/private",
            "/Applications", "/Applications/Utilities", "/Library",
            "/Library/Application Support", "/Library/Caches", "/Library/Preferences",
            "/Library/LaunchAgents", "/Library/LaunchDaemons", "/Library/Logs",
        ]
        let home = FileSystem.home.path
        set.insert(home)
        for sub in ["Library", "Library/Application Support", "Library/Caches",
                    "Library/Preferences", "Library/Containers", "Library/Group Containers",
                    "Library/Logs", "Library/LaunchAgents", "Library/Saved Application State",
                    "Documents", "Desktop", "Downloads"] {
            set.insert((home as NSString).appendingPathComponent(sub))
        }
        return set
    }

    /// Roots under which deletion is permitted at all.
    private static var allowedPrefixes: [String] {
        let home = FileSystem.home.path
        return [
            "/Applications/",
            (home as NSString).appendingPathComponent("Applications") + "/",
            (home as NSString).appendingPathComponent("Library") + "/",
            "/Library/",
        ]
    }

    enum Rejection: Error, LocalizedError {
        case forbiddenPath(String)
        case outsideAllowedRoots(String)
        case tooShallow(String)

        var errorDescription: String? {
            switch self {
            case .forbiddenPath(let p):      return "Refused to delete a protected location: \(p)"
            case .outsideAllowedRoots(let p): return "Refused to delete outside known app locations: \(p)"
            case .tooShallow(let p):          return "Refused to delete a top-level system folder: \(p)"
            }
        }
    }

    /// Throws `Rejection` if the URL is unsafe; returns normally if it is safe.
    static func validate(_ url: URL) throws {
        let path = (url.standardizedFileURL.path as NSString).standardizingPath

        if path.isEmpty || forbiddenExact.contains(path) {
            throw Rejection.forbiddenPath(path)
        }

        // Must contain at least one app-specific component beyond an allowed root.
        guard let prefix = allowedPrefixes.first(where: { path.hasPrefix($0) }) else {
            throw Rejection.outsideAllowedRoots(path)
        }

        let remainder = String(path.dropFirst(prefix.count))
        if remainder.isEmpty || remainder.contains("..") {
            throw Rejection.tooShallow(path)
        }
    }

    static func isSafe(_ url: URL) -> Bool {
        (try? validate(url)) != nil
    }
}
