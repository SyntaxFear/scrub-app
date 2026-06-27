import SwiftUI
import AppKit

/// Gates the whole app behind the required sign-in wall. Scanning only starts once
/// the user is signed in.
struct RootView: View {
    @Environment(AuthStore.self) private var auth
    let store: AppStore

    var body: some View {
        switch auth.state {
        case .unknown:
            ProgressView()
                .controlSize(.large)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(nsColor: .windowBackgroundColor))
                .task { await auth.restore() }
        case .signedOut:
            AuthWallView()
        case .signedIn:
            ContentView()
                .environment(store)
                .onAppear {
                    store.start()
                    LoginItem.syncAtLaunch()
                }
        }
    }
}
