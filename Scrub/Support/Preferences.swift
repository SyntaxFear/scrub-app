import Foundation

/// Central registry of user-facing preference keys and their defaults. Views bind
/// to these with `@AppStorage(PreferenceKey.…)`; services read them through the
/// typed accessors below. Keeping the keys and defaults in one place stops the
/// two sides from drifting apart.
enum PreferenceKey {
    static let automaticUpdates = "automaticUpdates"
    static let showSizeHint     = "showSizeHint"
    static let launchAtLogin    = "launchAtLogin"
    static let showMenuBarIcon  = "showMenuBarIcon"
    /// The last app version whose "What's New" the user has seen.
    static let lastSeenVersion  = "lastSeenVersion"
}

enum Preferences {
    static let websiteURL = URL(string: "https://scrubmac.app")!
    static let contactEmail = "hello@scrubmac.app"
    static let githubURL = URL(string: "https://github.com/SyntaxFear/scrub-app")!

    /// Call once at launch, before any view or service reads a value, so unset
    /// keys resolve to these defaults.
    static func registerDefaults() {
        UserDefaults.standard.register(defaults: [
            // The signed Sparkle appcast is live, so new installs should keep
            // themselves current without requiring a manual check.
            PreferenceKey.automaticUpdates: true,
            PreferenceKey.showSizeHint:     true,
            PreferenceKey.launchAtLogin:    true,
            PreferenceKey.showMenuBarIcon:  true,
        ])
    }

    static var automaticUpdates: Bool { UserDefaults.standard.bool(forKey: PreferenceKey.automaticUpdates) }
    static var showSizeHint:     Bool { UserDefaults.standard.bool(forKey: PreferenceKey.showSizeHint) }
    static var launchAtLogin:    Bool { UserDefaults.standard.bool(forKey: PreferenceKey.launchAtLogin) }
    static var showMenuBarIcon:  Bool { UserDefaults.standard.bool(forKey: PreferenceKey.showMenuBarIcon) }

    static var lastSeenVersion: String? {
        get { UserDefaults.standard.string(forKey: PreferenceKey.lastSeenVersion) }
        set { UserDefaults.standard.set(newValue, forKey: PreferenceKey.lastSeenVersion) }
    }

    /// The running app's short version string (CFBundleShortVersionString), e.g. "1.1".
    static var currentVersion: String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0"
    }

    /// The running app's build string (CFBundleVersion).
    static var currentBuild: String {
        (Bundle.main.infoDictionary?["CFBundleVersion"] as? String) ?? "1"
    }
}
