import Foundation

/// One released version's user-facing highlights. Bundled with the app (works
/// offline) and reused as the body of the "What's New" screen shown after an update.
struct ChangelogEntry: Codable, Identifiable, Sendable {
    let version: String
    let build: String
    let date: String
    let minimumMacOS: String
    let highlights: [String]
    let sha256: String
    let fileSize: Int64
    let latestPath: String
    let archivePath: String
    var id: String { version }
}

enum Changelog {

    private struct Manifest: Codable {
        let schemaVersion: Int
        let releases: [ChangelogEntry]
    }

    /// Newest first. `Releases.json` is the shared source for app notes and the
    /// landing site's release metadata.
    static let entries: [ChangelogEntry] = loadEntries()

    static var latest: ChangelogEntry? { entries.first }

    /// The notes for a specific version, falling back to the latest entry.
    static func entry(for version: String) -> ChangelogEntry? {
        entries.first { $0.version == version } ?? latest
    }

    private static func loadEntries() -> [ChangelogEntry] {
        guard let url = Bundle.main.url(forResource: "Releases", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let manifest = try? JSONDecoder().decode(Manifest.self, from: data),
              manifest.schemaVersion == 1,
              !manifest.releases.isEmpty else {
            return fallbackEntries
        }
        return manifest.releases
    }

    private static let fallbackEntries: [ChangelogEntry] = [
        ChangelogEntry(
            version: "1.4",
            build: "5",
            date: "2026-06-28",
            minimumMacOS: "14.0",
            highlights: [
                "Installer DMGs now open with a familiar drag-to-Applications layout.",
                "Added an Applications shortcut inside the DMG so installation is clearer.",
                "Kept the signed, notarized direct download and Sparkle update flow intact.",
            ],
            sha256: "",
            fileSize: 0,
            latestPath: "/Scrub.dmg",
            archivePath: "/releases/Scrub-1.4.dmg"
        ),
        ChangelogEntry(
            version: "1.3",
            build: "4",
            date: "2026-06-28",
            minimumMacOS: "14.0",
            highlights: [
                "Automatic updates are now enabled by default for new installs.",
                "Cleaned up the Settings About tab by removing the internal bundle identifier.",
                "Refreshed the signed latest download for the landing site and updater.",
            ],
            sha256: "",
            fileSize: 0,
            latestPath: "/Scrub.dmg",
            archivePath: "/releases/Scrub-1.3.dmg"
        ),
        ChangelogEntry(
            version: "1.2",
            build: "3",
            date: "2026-06-28",
            minimumMacOS: "14.0",
            highlights: [
                "Fixed ChatGPT assistant streaming so answers appear reliably instead of getting stuck on Thinking.",
                "Separated What's New from the AI Assistant action and added a clean Settings About tab.",
                "Added public project links for the website, contact email, and GitHub repository.",
            ],
            sha256: "",
            fileSize: 0,
            latestPath: "/Scrub.dmg",
            archivePath: "/releases/Scrub-1.2.dmg"
        ),
        ChangelogEntry(
            version: "1.1",
            build: "1",
            date: "2026-06-28",
            minimumMacOS: "14.0",
            highlights: [
                "Added manifest-backed release notes shared by the app and landing site.",
                "Added a ChatGPT/Codex cleanup assistant for read-only, metadata-only recommendations.",
                "Added an assistant drawer with app, leftover, and row-level Ask actions.",
            ],
            sha256: "4c529c3a9e2aaf504098ae32cd7e982268f32671f1cada33d633b96159423f62",
            fileSize: 4_039_915,
            latestPath: "/Scrub.dmg",
            archivePath: "/releases/Scrub-1.1.dmg"
        ),
        ChangelogEntry(
            version: "1.0",
            build: "1",
            date: "2026-06-27",
            minimumMacOS: "14.0",
            highlights: [
                "Initial direct-download Scrub release for macOS.",
                "Find installed apps with related caches, preferences, containers, launch agents, and helpers.",
                "Scan leftovers from apps that were already removed.",
                "Move selected user files to Trash first for reversible cleanup.",
            ],
            sha256: "d961de42a75a44263763f7c66516d89fe43f244f1f268c6f539cd5925d2ec1f9",
            fileSize: 2_567_829,
            latestPath: "/Scrub.dmg",
            archivePath: "/releases/Scrub-1.0.dmg"
        ),
    ]
}
