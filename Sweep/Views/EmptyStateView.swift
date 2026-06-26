import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.slash")
                .font(.system(size: 52, weight: .light))
                .foregroundStyle(.tertiary)
            VStack(spacing: 6) {
                Text("Select an app to uninstall")
                    .font(.title3.weight(.medium))
                Text("Pick an app from the list, or drag one onto this window.\nScrub finds every related file so nothing gets left behind.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
