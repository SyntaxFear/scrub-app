import SwiftUI

/// Non-blocking banner prompting the user to grant Full Disk Access so scans
/// are complete. Dismisses itself once access is detected.
///
/// Full Disk Access only takes effect when the app is relaunched, so the flow is
/// two-stage: first send the user to System Settings, then — once they've been
/// there — offer to reopen the app, which is what actually applies the grant.
struct FullDiskAccessBanner: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text(store.didRequestFullDiskAccess
                     ? "Reopen Scrub to apply Full Disk Access"
                     : "Grant Full Disk Access for complete scans")
                    .font(.subheadline.weight(.medium))
                Text(store.didRequestFullDiskAccess
                     ? "macOS only applies the permission after a restart. Your work is not affected."
                     : "Without it, some apps' files (containers, mail, messages) stay hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if store.didRequestFullDiskAccess {
                Button("Open Settings…") { store.openFullDiskAccessSettings() }
                Button("Quit & Reopen") { FullDiskAccess.relaunch() }
                    .buttonStyle(.borderedProminent)
            } else {
                Button("Open Settings…") { store.openFullDiskAccessSettings() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 9)
        .background {
            // Opaque base + faint warm tint = solid, not translucent.
            ZStack {
                Color(nsColor: .windowBackgroundColor)
                Color.orange.opacity(0.10)
            }
        }
        .overlay(alignment: .bottom) { Divider() }
    }
}
