import SwiftUI

/// Banner prompting the user to grant Full Disk Access. Scrub can still open
/// without it, but scans are incomplete enough that the permission should read
/// as required setup rather than an optional enhancement.
///
/// Full Disk Access only takes effect when the app is relaunched, so the flow is
/// two-stage: first send the user to System Settings, then — once they've been
/// there — offer to reopen the app, which is what actually applies the grant.
struct FullDiskAccessBanner: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(Color.caution)
                .font(.system(size: 15, weight: .semibold))
            VStack(alignment: .leading, spacing: 1) {
                Text(store.didRequestFullDiskAccess
                     ? "Reopen Scrub to finish Full Disk Access setup"
                     : "Full Disk Access Required")
                    .font(.subheadline.weight(.semibold))
                Text(store.didRequestFullDiskAccess
                     ? "macOS applies this permission only after relaunch. Reopen now so scans can see all app files."
                     : "Scrub needs this to find containers, caches, mail, messages, and other protected leftovers.")
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
        // Share the toolbar's vibrancy so this reads as a native notification bar.
        .background(.bar)
        // An explicit bottom hairline so the permission bar is clearly bounded against
        // the content below — .bar's own edge isn't visible over this dark content, and
        // the toolbar separator handles the top edge.
        .overlay(alignment: .bottom) { Divider() }
    }
}
