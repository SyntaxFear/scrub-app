import Foundation

// The app's single entry point for software updates. Everything else (menu bar,
// Settings) talks only to `UpdaterService.shared`, so nothing else depends on
// Sparkle directly.
//
// This file activates automatically once the Sparkle package is added to the
// target — see docs/SPARKLE-SETUP.md. Until then the `#else` stub keeps the app
// building and running with update actions as harmless no-ops. The feed URL and
// the EdDSA public key (SUPublicEDKey) live in Info.plist (added in that setup).

#if canImport(Sparkle)
import Sparkle

final class UpdaterService {
    static let shared = UpdaterService()

    private let controller = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    private init() {
        let on = Preferences.automaticUpdates
        controller.updater.automaticallyChecksForUpdates = on
        controller.updater.automaticallyDownloadsUpdates = on
    }

    /// User-initiated check ("Check for Updates…").
    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    /// Mirrors the "Automatic updates" preference into Sparkle.
    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
        controller.updater.automaticallyDownloadsUpdates = enabled
    }
}

#else

final class UpdaterService {
    static let shared = UpdaterService()
    private init() {}

    func checkForUpdates() {
        NSLog("UpdaterService: Sparkle not linked yet — see docs/SPARKLE-SETUP.md")
    }

    func setAutomaticChecks(_ enabled: Bool) {}
}

#endif
