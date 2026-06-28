import Foundation

/// The kind of file an item represents. Drives grouping, sort order, and the
/// SF Symbol shown next to each row.
enum ItemCategory: String, CaseIterable, Sendable {
    case application
    case binarySupport          // helpers, login items, /Library/Application Support
    case applicationSupport
    case containers
    case groupContainers
    case caches
    case preferences
    case savedState
    case logs
    case httpStorages
    case webKit
    case cookies
    case applicationScripts
    case launchAgent            // ~/Library/LaunchAgents or /Library/LaunchAgents
    case launchDaemon           // /Library/LaunchDaemons (admin)
    case other

    var label: String {
        switch self {
        case .application:        return "Application"
        case .binarySupport:      return "Support Files"
        case .applicationSupport: return "Application Support"
        case .containers:         return "Container"
        case .groupContainers:    return "Group Container"
        case .caches:             return "Cache"
        case .preferences:        return "Preferences"
        case .savedState:         return "Saved State"
        case .logs:               return "Logs"
        case .httpStorages:       return "Web Storage"
        case .webKit:             return "WebKit Data"
        case .cookies:            return "Cookies"
        case .applicationScripts: return "App Scripts"
        case .launchAgent:        return "Launch Agent"
        case .launchDaemon:       return "Launch Daemon"
        case .other:              return "Other"
        }
    }

    var systemImage: String {
        switch self {
        case .application:        return "app.dashed"
        case .binarySupport:      return "wrench.and.screwdriver"
        case .applicationSupport: return "folder"
        case .containers:         return "shippingbox"
        case .groupContainers:    return "square.stack.3d.up"
        case .caches:             return "bolt.horizontal"
        case .preferences:        return "gearshape"
        case .savedState:         return "macwindow"
        case .logs:               return "doc.text"
        case .httpStorages:       return "globe"
        case .webKit:             return "safari"
        case .cookies:            return "circle.grid.cross"
        case .applicationScripts: return "applescript"
        case .launchAgent:        return "person.badge.clock"
        case .launchDaemon:       return "gearshape.2"
        case .other:              return "doc"
        }
    }

    /// Lower comes first in the detail table.
    var sortOrder: Int {
        switch self {
        case .application:        return 0
        case .binarySupport:      return 1
        case .applicationSupport: return 2
        case .containers:         return 3
        case .groupContainers:    return 4
        case .caches:             return 5
        case .preferences:        return 6
        case .savedState:         return 7
        case .logs:               return 8
        case .httpStorages:       return 9
        case .webKit:             return 10
        case .cookies:            return 11
        case .applicationScripts: return 12
        case .launchAgent:        return 13
        case .launchDaemon:       return 14
        case .other:              return 15
        }
    }
}

/// How sure we are an item belongs to the app. `.exact` items match the bundle
/// identifier. `.likely` items match on the app's display name or Team ID; they
/// carry a "likely" badge and are selected by default only when the app's
/// identity is independently corroborated by an exact match (see
/// `AppStore.defaultSelection(for:)`), and left unchecked otherwise.
enum MatchConfidence: Sendable {
    case exact
    case likely
}

/// Which security domain a file lives in. `.user` files can be moved to the
/// Trash without elevation; `.admin` files require an administrator password
/// and are removed permanently.
enum FileDomain: Sendable {
    case user
    case admin
}
