import SwiftUI

struct ContentView: View {
    @Environment(AppStore.self) private var store
    @State private var isDropTargeted = false

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            SidebarView()
                .navigationSplitViewColumnWidth(min: 240, ideal: 286, max: 380)
        } detail: {
            DetailView()
                .navigationSplitViewColumnWidth(min: 460, ideal: 640)
        }
        .toolbar {
            if store.showWhatsNewChip {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        store.openWhatsNew()
                    } label: {
                        Label("What’s New", systemImage: "sparkles")
                    }
                    .help("See what’s new in this version")
                }
            }

            ToolbarItem(placement: .primaryAction) {
                Button {
                    if store.mode == .apps {
                        Task { await store.loadApps() }
                    } else {
                        Task { await store.refreshLeftovers() }
                    }
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
                .labelStyle(.iconOnly)
                .help("Rescan")
                .accessibilityLabel("Rescan")
            }

            ToolbarItem(placement: .primaryAction) {
                SettingsLink {
                    Label("Settings", systemImage: "gearshape")
                }
                .labelStyle(.iconOnly)
                .help("Settings")
                .accessibilityLabel("Settings")
            }
        }
        .navigationTitle("Scrub")
        .searchable(text: $store.searchText, prompt: store.mode == .apps ? "Search apps" : "Search leftovers")
        .toolbarBackground(.visible, for: .windowToolbar)
        .background(WindowAccessor())
        .onChange(of: store.mode) { _, newValue in
            if newValue == .leftovers { store.enterLeftoversMode() }
        }
        .onReceive(NotificationCenter.default.publisher(
            for: NSApplication.didBecomeActiveNotification)) { _ in
            // Re-probe when the user returns from System Settings. This clears the
            // banner automatically if the grant is already live in this process.
            store.refreshFullDiskAccess()
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !store.fullDiskAccessGranted {
                FullDiskAccessBanner()
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: store.fullDiskAccessGranted)
        .dropDestination(for: URL.self) { urls, _ in
            store.handleDrop(urls: urls)
            return true
        } isTargeted: { isDropTargeted = $0 }
        .overlay {
            if isDropTargeted { DropOverlay() }
        }
        .sheet(isPresented: $store.showingConfirmation) {
            RemovalConfirmationSheet()
        }
        .sheet(isPresented: $store.showingWhatsNew) {
            if let entry = Changelog.entry(for: Preferences.currentVersion) {
                WhatsNewView(entry: entry)
            }
        }
        .alert("Cleanup Complete", isPresented: $store.showingOutcome, presenting: store.lastOutcome) { _ in
            Button("OK", role: .cancel) { }
        } message: { outcome in
            Text(outcomeMessage(outcome))
        }
    }

    private func outcomeMessage(_ outcome: Remover.Outcome) -> String {
        var lines: [String] = []
        if !outcome.trashed.isEmpty {
            lines.append("\(outcome.trashed.count) item\(outcome.trashed.count == 1 ? "" : "s") moved to the Trash.")
        }
        if !outcome.removedWithAdmin.isEmpty {
            lines.append("\(outcome.removedWithAdmin.count) system item\(outcome.removedWithAdmin.count == 1 ? "" : "s") removed.")
        }
        if !outcome.failures.isEmpty {
            lines.append("\(outcome.failures.count) item\(outcome.failures.count == 1 ? "" : "s") could not be removed:")
            lines.append(contentsOf: outcome.failures.prefix(5).map { "• \($0.message)" })
        }
        if lines.isEmpty { lines.append("Nothing was removed.") }
        return lines.joined(separator: "\n")
    }
}

/// Forces the window opaque so the content reads as solid, not translucent.
private struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else { return }
            window.isOpaque = true
            window.backgroundColor = .windowBackgroundColor
            // Persistent hairline under the toolbar so the header reads as a distinct
            // bar separated from the content, the way first-party apps do (otherwise
            // the unified toolbar only shows a separator while content scrolls).
            window.titlebarSeparatorStyle = .line
        }
        return view
    }
    func updateNSView(_ nsView: NSView, context: Context) {}
}

/// Translucent highlight shown while an app bundle is dragged over the window.
private struct DropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(Color.accentColor, style: StrokeStyle(lineWidth: 2, dash: [8]))
                .padding(16)
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.app")
                    .font(.system(size: 46))
                    .accessibilityHidden(true)
                Text("Drop an app to uninstall it")
                    .font(.title3.weight(.medium))
            }
            .foregroundStyle(Color.accentColor)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
