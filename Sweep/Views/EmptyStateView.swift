import SwiftUI

struct EmptyStateView: View {
    var body: some View {
        ContentUnavailableView(
            "Select an app to uninstall",
            systemImage: "trash.slash",
            description: Text("Pick an app from the list, or drag one onto this window. Scrub finds every related file so nothing gets left behind.")
        )
    }
}
