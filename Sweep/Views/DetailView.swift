import SwiftUI

struct DetailView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Group {
            if store.isScanningDetail {
                ProgressView("Finding related files…")
                    .controlSize(.small)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let app = store.selectedApp {
                detail(header: AnyView(AppHeader(app: app, total: headerTotal)))
            } else if let orphan = store.selectedOrphan {
                detail(header: AnyView(OrphanHeader(group: orphan)))
            } else {
                EmptyStateView()
            }
        }
    }

    private var headerTotal: Int64 {
        store.detailItems.reduce(0) { $0 + max(0, $1.size) }
    }

    // MARK: - Shared detail body

    private func detail(header: AnyView) -> some View {
        VStack(spacing: 0) {
            header
            Divider()
            ItemsTable()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom, spacing: 0) { RemovalFooter() }
    }
}

// MARK: - Headers

private struct AppHeader: View {
    @Environment(AppStore.self) private var store
    let app: InstalledApp
    let total: Int64

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(url: app.url, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.title2.weight(.semibold))
                Text("Version \(app.version)  ·  \(store.detailItems.count) related items  ·  \(Format.size(total)) total")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if store.isSelectedAppRunning {
                    Label("Running — it will be quit before removal", systemImage: "bolt.horizontal.circle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

private struct OrphanHeader: View {
    let group: OrphanGroup

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 38))
                .foregroundStyle(.secondary)
                .frame(width: 52, height: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(group.displayName).font(.title2.weight(.semibold))
                Text(group.inferredBundleID)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Label("Leftover from an app that's no longer installed", systemImage: "questionmark.circle")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
    }
}

// MARK: - Items table

private struct ItemsTable: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        Table(store.detailItems) {
            TableColumn("") { item in
                Toggle("", isOn: Binding(
                    get: { store.detailSelection.contains(item.url) },
                    set: { store.setItem(item.url, selected: $0) }
                ))
                .labelsHidden()
            }
            .width(28)

            TableColumn("Item") { item in
                HStack(spacing: 8) {
                    CategoryGlyph(category: item.category)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.displayName).lineLimit(1)
                        Text(item.abbreviatedPath)
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }

            TableColumn("Kind") { item in
                HStack(spacing: 6) {
                    Text(item.category.label)
                    if item.confidence == .likely {
                        Text("likely")
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                            .foregroundStyle(.secondary)
                    }
                    if item.domain == .admin {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }
                }
                .foregroundStyle(.secondary)
            }
            .width(min: 130, ideal: 150)

            TableColumn("Size") { item in
                Text(Format.size(item.size))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .width(min: 64, ideal: 80, max: 110)
        }
        .scrollContentBackground(.hidden)
    }
}
