import SwiftUI

struct DetailView: View {
    @Environment(AppStore.self) private var store
    @Environment(AssistantStore.self) private var assistant

    var body: some View {
        Group {
            if store.isScanningDetail {
                ProgressView("Finding related files…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let app = store.selectedApp {
                detail(header: AnyView(AppHeader(app: app, total: headerTotal, apparentTotal: headerApparentTotal)))
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

    private var headerApparentTotal: Int64 {
        store.detailItems.reduce(0) { $0 + max(0, $1.apparentSize) }
    }

    // MARK: - Shared detail body

    private func detail(header: AnyView) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 0) {
                header
                Divider()
                ItemsTable()
            }
            .background(Color(nsColor: .windowBackgroundColor))
            .safeAreaInset(edge: .bottom, spacing: 0) { RemovalFooter() }

            if assistant.isDrawerVisible {
                Divider()
                AssistantDrawerView()
            }
        }
    }
}

// MARK: - Headers

private struct AppHeader: View {
    @Environment(AppStore.self) private var store
    @AppStorage(PreferenceKey.showSizeHint) private var showSizeHint = true
    let app: InstalledApp
    let total: Int64
    let apparentTotal: Int64

    var body: some View {
        HStack(spacing: 14) {
            AppIconView(url: app.url, size: 52)
            VStack(alignment: .leading, spacing: 3) {
                Text(app.name).font(.title2.weight(.semibold))
                HStack(spacing: 6) {
                    Text("Version \(app.version)  ·  \(store.detailItems.count) related items  ·  \(Format.size(total)) total")
                    if store.isSizingDetail {
                        ProgressView().controlSize(.mini)
                    } else if showSizeHint, let hint = Format.listedHint(onDisk: total, apparent: apparentTotal) {
                        Text("· \(hint)").foregroundStyle(.secondary)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                if store.isSelectedAppRunning {
                    Label("Running — it will be quit before removal", systemImage: "bolt.horizontal.circle")
                        .font(.caption)
                        .foregroundStyle(Color.caution)
                }
            }
            Spacer()
        }
        .padding(.horizontal, Metrics.contentInset)
        .padding(.vertical, 16)
    }
}

private struct OrphanHeader: View {
    let group: OrphanGroup

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "shippingbox.fill")
                .font(.system(size: 44))
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
        .padding(.horizontal, Metrics.contentInset)
        .padding(.vertical, 16)
    }
}

// MARK: - Items table

/// The list of related files, as a native macOS `Table`: sortable column headers,
/// resizable columns, native row striping / hover / selection, and a leading
/// checkbox column that marks each item for removal. Selecting rows (highlight) is
/// kept separate from the removal checkboxes so the destructive set stays explicit.
private struct ItemsTable: View {
    @Environment(AppStore.self) private var store
    @Environment(AssistantStore.self) private var assistant
    @AppStorage(PreferenceKey.showSizeHint) private var showSizeHint = true

    @State private var sortOrder: [KeyPathComparator<RelatedItem>] = [
        KeyPathComparator(\.category.sortOrder, order: .forward)
    ]
    @State private var rowSelection = Set<RelatedItem.ID>()

    private var rows: [RelatedItem] {
        store.detailItems.sorted(using: sortOrder)
    }

    var body: some View {
        Table(rows, selection: $rowSelection, sortOrder: $sortOrder) {
            TableColumn("") { item in
                Toggle("", isOn: Binding(
                    get: { store.detailSelection.contains(item.url) },
                    set: { store.setItem(item.url, selected: $0) }
                ))
                .labelsHidden()
                .toggleStyle(.checkbox)
                .accessibilityLabel("Include \(item.displayName) in removal")
            }
            .width(34)

            TableColumn("Item", value: \.displayName) { item in
                HStack(spacing: 8) {
                    CategoryGlyph(category: item.category)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(item.displayName).lineLimit(1)
                        Text(item.abbreviatedPath)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }
            }
            .width(min: 200, ideal: 320)

            TableColumn("Kind", value: \.category.sortOrder) { item in
                HStack(spacing: 6) {
                    Text(item.category.label)
                    if item.confidence == .likely {
                        Text("Likely")
                            .font(.caption2)
                            .padding(.horizontal, 5).padding(.vertical, 1)
                            .background(.quaternary, in: Capsule())
                            .help("Matched by the app's name, not its bundle identifier")
                    }
                    if item.vendorShared {
                        Image(systemName: "person.2.fill")
                            .foregroundStyle(Color.caution)
                            .help("Shared across this vendor's apps — may still hold data for their other apps")
                            .accessibilityLabel("Shared across this vendor's apps")
                    }
                    if item.domain == .admin {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(Color.caution)
                            .help("Requires an administrator password — removed permanently, not moved to Trash")
                            .accessibilityLabel("Requires administrator password")
                    }
                }
                .foregroundStyle(.secondary)
            }
            .width(min: 110, ideal: 170)

            TableColumn("Size", value: \.size) { item in
                sizeCell(item)
            }
            .width(min: 80, ideal: 100)

            TableColumn("") { item in
                rowActions(item)
            }
            .width(58)
        }
        .contextMenu(forSelectionType: RelatedItem.ID.self) { ids in
            contextMenu(for: ids)
        }
    }

    @ViewBuilder private func sizeCell(_ item: RelatedItem) -> some View {
        if item.size < 0 {
            // Right-aligned placeholder so the trailing edge stays put while the
            // real value is still being measured in the background.
            HStack { Spacer(); ProgressView().controlSize(.mini) }
        } else {
            VStack(alignment: .trailing, spacing: 1) {
                Text(Format.size(item.size)).monospacedDigit()
                if showSizeHint, let hint = Format.listedHint(onDisk: item.size, apparent: item.apparentSize) {
                    Text(hint).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    @ViewBuilder private func rowActions(_ item: RelatedItem) -> some View {
        HStack(spacing: 10) {
            Button {
                assistant.open(focusedItem: item)
            } label: { Image(systemName: "sparkles") }
                .help("Ask AI about this item")
                .accessibilityLabel("Ask AI about \(item.displayName)")
            Button { Finder.reveal(item.url) } label: { Image(systemName: "folder") }
                .help("Reveal in Finder")
                .accessibilityLabel("Reveal \(item.displayName) in Finder")
            Button { store.requestRemoval(of: item) } label: { Image(systemName: "trash") }
                .help("Delete this item")
                .accessibilityLabel("Delete \(item.displayName)")
        }
        .buttonStyle(.borderless)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder private func contextMenu(for ids: Set<RelatedItem.ID>) -> some View {
        let items = store.detailItems.filter { ids.contains($0.id) }
        if items.count == 1, let item = items.first {
            Button("Reveal in Finder") { Finder.reveal(item.url) }
            Button("Open") { Finder.open(item.url) }
            Divider()
            Button("Delete", role: .destructive) { store.requestRemoval(of: item) }
        } else if !items.isEmpty {
            Button("Delete \(items.count) Items", role: .destructive) {
                store.requestRemoval(of: items)
            }
        }
    }
}
