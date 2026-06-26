import AppKit

/// Detects whether the app has been granted Full Disk Access, which it needs to
/// see TCC-protected locations like other apps' containers completely.
///
/// Two macOS realities shape this code:
///
/// 1. **The grant only takes effect at process launch.** TCC evaluates Full Disk
///    Access once, when the process starts, and caches the answer for the
///    process's lifetime. Toggling the permission in System Settings while the
///    app is running does *not* update the running process — so an in-place
///    "recheck" can never observe a permission the user just granted. The app
///    must relaunch. `relaunch()` exists for exactly this.
///
/// 2. **POSIX `access()` (`FileManager.isReadableFile`) does not reflect TCC.**
///    The only reliable probe is to actually `open()` a protected file and see
///    whether the kernel lets us. That is what `isGranted()` does.
enum FullDiskAccess {

    /// Files that exist on every Mac and can only be read with Full Disk Access.
    /// The system-level TCC database is the canonical probe; the user-level copy
    /// is a fallback in the unlikely event the system one is missing.
    private static var probePaths: [String] {
        [
            "/Library/Application Support/com.apple.TCC/TCC.db",
            NSHomeDirectory() + "/Library/Application Support/com.apple.TCC/TCC.db",
        ]
    }

    /// Probes a protected path by attempting a real read. Returns `true` only if
    /// the kernel actually lets us open it — which is what Full Disk Access gates.
    static func isGranted() -> Bool {
        for path in probePaths {
            guard FileManager.default.fileExists(atPath: path) else { continue }
            if let handle = try? FileHandle(forReadingFrom: URL(fileURLWithPath: path)) {
                try? handle.close()
                return true
            }
            // The file exists but the kernel refused the open → access denied.
            return false
        }
        // Neither probe exists (extremely unusual). Don't nag the user.
        return true
    }

    /// Opens System Settings directly at Privacy → Full Disk Access.
    @MainActor
    static func openSettings() {
        let url = URL(string:
            "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
        NSWorkspace.shared.open(url)
    }

    /// Relaunches the app so a newly granted Full Disk Access permission takes
    /// effect. Because TCC only re-evaluates the grant at launch, this is the
    /// *only* reliable way to apply a permission the user just toggled.
    ///
    /// A short-lived detached shell waits for this process to exit, then reopens
    /// the bundle — avoiding the race where the new instance starts before the
    /// old one has released single-instance state.
    @MainActor
    static func relaunch() {
        let bundlePath = Bundle.main.bundlePath
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/bin/sh")
        task.arguments = ["-c", "sleep 0.4; /usr/bin/open \(shellQuote(bundlePath))"]
        try? task.run()
        NSApp.terminate(nil)
    }

    /// Wraps a path in single quotes, escaping any embedded single quotes.
    private static func shellQuote(_ s: String) -> String {
        "'" + s.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
