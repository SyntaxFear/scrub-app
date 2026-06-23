import AppKit

/// Detects and quits a running application so its files aren't locked during
/// removal.
@MainActor
enum RunningAppMonitor {

    static func isRunning(_ app: InstalledApp) -> Bool {
        !runningInstances(of: app).isEmpty
    }

    static func runningInstances(of app: InstalledApp) -> [NSRunningApplication] {
        guard !app.bundleID.isEmpty else {
            // Fall back to matching by bundle URL when there's no identifier.
            return NSWorkspace.shared.runningApplications.filter {
                $0.bundleURL?.standardizedFileURL == app.url.standardizedFileURL
            }
        }
        return NSRunningApplication.runningApplications(withBundleIdentifier: app.bundleID)
    }

    /// Asks the app to quit, escalating to a forced terminate if it's still
    /// running after a short grace period. Returns true once nothing is left
    /// running.
    static func quit(_ app: InstalledApp) async -> Bool {
        let instances = runningInstances(of: app)
        guard !instances.isEmpty else { return true }

        for instance in instances { instance.terminate() }

        // Give them up to ~3 seconds to exit gracefully.
        for _ in 0..<6 {
            try? await Task.sleep(nanoseconds: 500_000_000)
            if !isRunning(app) { return true }
        }

        for instance in runningInstances(of: app) { instance.forceTerminate() }
        try? await Task.sleep(nanoseconds: 500_000_000)
        return !isRunning(app)
    }
}
