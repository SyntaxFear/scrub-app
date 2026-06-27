import Foundation

/// One released version's user-facing highlights. Bundled with the app (works
/// offline) and reused as the body of the "What's New" screen shown after an update.
struct ChangelogEntry: Identifiable, Sendable {
    let version: String
    let highlights: [String]
    var id: String { version }
}

enum Changelog {

    /// Newest first. Add a new entry at the top with every release; the entry whose
    /// `version` matches the running build is what "What's New" shows after updating.
    static let entries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.1",
            highlights: [
                "Sign in with Apple, Google, or email to set up Scrub.",
                "Automatic updates — Scrub keeps itself current and verified.",
                "New menu bar icon with quick actions, including Empty Trash.",
                "Settings window: launch at login, menu bar, and updates.",
                "Accurate sizes for sparse data like VMs, with a “listed” hint.",
                "More complete uninstalls: an app’s own data folders are now selected by default.",
            ]
        ),
    ]

    static var latest: ChangelogEntry? { entries.first }

    /// The notes for a specific version, falling back to the latest entry.
    static func entry(for version: String) -> ChangelogEntry? {
        entries.first { $0.version == version } ?? latest
    }
}
