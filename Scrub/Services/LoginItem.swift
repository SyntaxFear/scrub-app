import Foundation
import ServiceManagement

/// Registers Scrub as a macOS login item via `SMAppService` (macOS 13+). The
/// "Launch at login" preference defaults ON, so on the very first run we register
/// once; after that we mirror the *real* system status back into the preference so
/// the Settings toggle reflects reality — and so we never fight a user who turned
/// it off in System Settings → General → Login Items.
enum LoginItem {

    private static let didInitialSyncKey = "didInitialLoginSync"

    /// Whether Scrub is currently registered to launch at login.
    static var isEnabled: Bool {
        SMAppService.mainApp.status == .enabled
    }

    /// Registers or unregisters to match `enabled`. Errors are logged, not fatal
    /// (e.g. the user revoked approval, or we're running from an unsigned build).
    static func setEnabled(_ enabled: Bool) {
        do {
            switch (enabled, SMAppService.mainApp.status) {
            case (true, let s) where s != .enabled:
                try SMAppService.mainApp.register()
            case (false, .enabled):
                try SMAppService.mainApp.unregister()
            default:
                break
            }
        } catch {
            NSLog("LoginItem: setEnabled(\(enabled)) failed: \(error.localizedDescription)")
        }
    }

    /// Call once at launch. First run honors the default-ON preference; every run
    /// then writes the actual status back into the preference so the UI is honest.
    static func syncAtLaunch() {
        if !UserDefaults.standard.bool(forKey: didInitialSyncKey) {
            setEnabled(Preferences.launchAtLogin)
            UserDefaults.standard.set(true, forKey: didInitialSyncKey)
        }
        UserDefaults.standard.set(isEnabled, forKey: PreferenceKey.launchAtLogin)
    }
}
