import AppKit

/// Detects whether the app has been granted Full Disk Access, which it needs to
/// see TCC-protected locations like other apps' containers completely.
enum FullDiskAccess {

    /// Probes a protected path that is unreadable without Full Disk Access.
    static func isGranted() -> Bool {
        let probe = FileSystem.home
            .appendingPathComponent("Library/Application Support/com.apple.TCC/TCC.db")
        // If the file exists and we can open it for reading, access is granted.
        // If it exists but can't be read, access is denied. If it doesn't exist
        // at all (rare), assume granted so we don't nag unnecessarily.
        guard FileSystem.exists(probe) else { return true }
        return FileSystem.fm.isReadableFile(atPath: probe.path)
    }

    /// Opens System Settings directly at Privacy → Full Disk Access.
    @MainActor
    static func openSettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }
}
