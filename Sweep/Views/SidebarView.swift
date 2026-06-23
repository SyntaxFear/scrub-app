import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        Group {
            switch store.mode {
            case .apps:      appList(store)
            case .leftovers: leftoverList(store)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Apps

    @ViewBuilder
    private func appList(_ store: AppStore) -> some View {
        @Bindable var store = store

        if store.isLoadingApps && store.apps.isEmpty {
            ProgressView("Scanning Applications…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .controlSize(.small)
        } else {
            List(selection: $store.selectedAppID) {
                Section("Applications") {
                    ForEach(store.filteredApps) { app in
                        AppRow(app: app).tag(app.id)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: store.selectedAppID) { _, newValue in
                store.selectApp(newValue)
            }
        }
    }

    // MARK: - Leftovers

    @ViewBuilder
    private func leftoverList(_ store: AppStore) -> some View {
        @Bindable var store = store

        if store.isScanningLeftovers && store.leftovers.isEmpty {
            ProgressView("Looking for leftovers…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .controlSize(.small)
        } else if store.leftovers.isEmpty {
            ContentUnavailableView(
                "No Leftovers Found",
                systemImage: "sparkles",
                description: Text("Files from apps you've already deleted will appear here.")
            )
        } else {
            List(selection: $store.selectedOrphanID) {
                Section("From deleted apps") {
                    ForEach(store.filteredLeftovers) { group in
                        LeftoverRow(group: group).tag(group.id)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .onChange(of: store.selectedOrphanID) { _, newValue in
                store.selectOrphan(newValue)
            }
        }
    }
}

private struct AppRow: View {
    let app: InstalledApp

    var body: some View {
        HStack(spacing: 9) {
            AppIconView(url: app.url, size: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(app.name).lineLimit(1)
                if app.bundleNeedsAdmin {
                    Label("System", systemImage: "lock.fill")
                        .labelStyle(.titleAndIcon)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            Spacer(minLength: 4)
            Text(Format.size(app.size))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}

private struct LeftoverRow: View {
    let group: OrphanGroup

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "shippingbox")
                .foregroundStyle(.secondary)
                .frame(width: 22, height: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(group.displayName).lineLimit(1)
                Text("\(group.items.count) item\(group.items.count == 1 ? "" : "s")")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 4)
            Text(Format.size(group.totalSize))
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.vertical, 2)
    }
}
