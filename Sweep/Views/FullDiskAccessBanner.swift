import SwiftUI

/// Non-blocking banner prompting the user to grant Full Disk Access so scans
/// are complete. Dismisses itself once access is detected.
struct FullDiskAccessBanner: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.shield.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 1) {
                Text("Grant Full Disk Access for complete scans")
                    .font(.subheadline.weight(.medium))
                Text("Without it, some apps' files (containers, mail, messages) stay hidden.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Recheck") { store.refreshFullDiskAccess() }
            Button("Open Settings…") { FullDiskAccess.openSettings() }
                .buttonStyle(.borderedProminent)
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
