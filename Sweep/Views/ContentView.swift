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
            ToolbarItem(placement: .principal) {
                Picker("View", selection: $store.mode) {
                    Text("Applications").tag(AppStore.Mode.apps)
                    Text("Leftovers").tag(AppStore.Mode.leftovers)
                }
                .pickerStyle(.segmented)
                .fixedSize()
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    if store.mode == .apps {
                        Task { await store.loadApps() }
                    } else {
                        Task { await store.refreshLeftovers() }
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Rescan")
            }
        }
        .searchable(text: $store.searchText, prompt: store.mode == .apps ? "Search apps" : "Search leftovers")
        .onChange(of: store.mode) { _, newValue in
            if newValue == .leftovers { store.enterLeftoversMode() }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if !store.fullDiskAccessGranted {
                FullDiskAccessBanner()
            }
        }
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

/// Translucent overlay shown while an app bundle is dragged over the window.
private struct DropOverlay: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(.thinMaterial)
            VStack(spacing: 12) {
                Image(systemName: "arrow.down.app.dashed")
                    .font(.system(size: 46, weight: .light))
                Text("Drop an app to uninstall it")
                    .font(.title3.weight(.medium))
            }
            .foregroundStyle(.secondary)
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}
