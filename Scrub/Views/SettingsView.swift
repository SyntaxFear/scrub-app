import SwiftUI

/// The ⌘, Settings window: General + Updates tabs.
struct SettingsView: View {
    var body: some View {
        TabView {
            GeneralSettings()
                .tabItem { Label("General", systemImage: "gearshape") }
            UpdatesSettings()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(height: 340)
    }
}

private struct GeneralSettings: View {
    @Environment(AuthStore.self) private var auth
    @AppStorage(PreferenceKey.launchAtLogin) private var launchAtLogin = true
    @AppStorage(PreferenceKey.showMenuBarIcon) private var showMenuBarIcon = true
    @AppStorage(PreferenceKey.showSizeHint) private var showSizeHint = true

    var body: some View {
        Form {
            if case .signedIn(let user) = auth.state {
                Section("Account") {
                    LabeledContent("Signed in as") {
                        Text(user.email)
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                    }
                    Button("Sign Out") { auth.signOut() }
                }
            }
            Section("General") {
                Toggle("Launch Scrub at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, enabled in
                        LoginItem.setEnabled(enabled)
                    }
                Toggle("Show Scrub in the menu bar", isOn: $showMenuBarIcon)
            }
            Section {
                Toggle("Show listed (apparent) size as a hint", isOn: $showSizeHint)
            } footer: {
                Text("“Listed” size is what Finder shows. Scrub’s main number is real on-disk space — what you actually free when you delete.")
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}

private struct UpdatesSettings: View {
    @AppStorage(PreferenceKey.automaticUpdates) private var automaticUpdates = false

    var body: some View {
        Form {
            Section {
                Toggle("Automatically download and install updates", isOn: $automaticUpdates)
                    .onChange(of: automaticUpdates) { _, enabled in
                        UpdaterService.shared.setAutomaticChecks(enabled)
                    }
            } footer: {
                Text("Updates are downloaded in the background and installed when you restart. Every update is signed, so only genuine Scrub releases can install.")
            }
            Section {
                LabeledContent("Current version", value: Preferences.currentVersion)
                Button("Check for Updates…") {
                    UpdaterService.shared.checkForUpdates()
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 460)
    }
}
