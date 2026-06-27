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
                        Text("· \(hint)").foregroundStyle(.tertiary)
                    }
                }
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

/// The file list with a proper header row: a master checkbox, sortable Item /
/// Kind / Size columns, and a labelled "Open" column. Built from a custom header
/// over a `List` so the header checkbox and per-column sorting align exactly with
/// the rows.
private struct ItemsTable: View {
    @Environment(AppStore.self) private var store
    @AppStorage(PreferenceKey.showSizeHint) private var showSizeHint = true

    enum Field { case name, kind, size }
    @State private var sortField: Field = .kind
    @State private var ascending = true

    // Column widths shared by the header and every row, so they line up exactly.
    private let wCheck:     CGFloat = 28
    private let wKind:      CGFloat = 160
    private let wSize:      CGFloat = 92
    private let wActions:   CGFloat = 64
    private let colSpacing: CGFloat = 10
    private let hInset:     CGFloat = 16
    private let vPad:       CGFloat = 7

    private var rows: [RelatedItem] {
        let items = store.detailItems
        let sorted: [RelatedItem]
        switch sortField {
        case .name:
            sorted = items.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .kind:
            sorted = items.sorted {
                $0.category.sortOrder != $1.category.sortOrder
                    ? $0.category.sortOrder < $1.category.sortOrder
                    : $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
            }
        case .size:
            sorted = items.sorted { max(0, $0.size) < max(0, $1.size) }
        }
        return ascending ? sorted : sorted.reversed()
    }

    private var allSelected: Bool {
        !store.detailItems.isEmpty && store.selectedItems.count == store.detailItems.count
    }

    var body: some View {
        VStack(spacing: 0) {
            headerRow
            Divider()
            // A plain ScrollView (not List) so the header and rows share the
            // exact same horizontal geometry and line up column-for-column.
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(rows) { item in
                        row(item)
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: Header

    private var headerRow: some View {
        HStack(spacing: colSpacing) {
            Toggle("", isOn: Binding(
                get: { allSelected },
                set: { $0 ? store.selectAllItems() : store.deselectAllItems() }
            ))
            .labelsHidden()
            .toggleStyle(.checkbox)
            .frame(width: wCheck, alignment: .center)
            .help(allSelected ? "Deselect all" : "Select all")

            sortButton("Item", .name).frame(maxWidth: .infinity, alignment: .leading)
            sortButton("Kind", .kind).frame(width: wKind, alignment: .leading)
            sortButton("Size", .size).frame(width: wSize, alignment: .trailing)
            Text("Actions").frame(width: wActions, alignment: .trailing)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.horizontal, hInset)
        .padding(.vertical, vPad)
    }

    private func sortButton(_ title: String, _ field: Field) -> some View {
        Button {
            if sortField == field { ascending.toggle() }
            else { sortField = field; ascending = true }
        } label: {
            HStack(spacing: 3) {
                Text(title)
                Image(systemName: ascending ? "chevron.up" : "chevron.down")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(sortField == field ? 1 : 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Row

    private func row(_ item: RelatedItem) -> some View {
        HStack(spacing: colSpacing) {
            Toggle("", isOn: Binding(
                get: { store.detailSelection.contains(item.url) },
                set: { store.setItem(item.url, selected: $0) }
            ))
            .labelsHidden()
            .frame(width: wCheck, alignment: .center)

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
            .frame(maxWidth: .infinity, alignment: .leading)

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
                Spacer(minLength: 0)
            }
            .foregroundStyle(.secondary)
            .frame(width: wKind, alignment: .leading)

            Group {
                if item.size < 0 {
                    ProgressView().controlSize(.mini)
                } else {
                    VStack(alignment: .trailing, spacing: 1) {
                        Text(Format.size(item.size)).monospacedDigit()
                        if showSizeHint, let hint = Format.listedHint(onDisk: item.size, apparent: item.apparentSize) {
                            Text(hint).font(.caption2).foregroundStyle(.tertiary)
                        }
                    }
                }
            }
            .foregroundStyle(.secondary)
            .frame(width: wSize, alignment: .trailing)

            HStack(spacing: 10) {
                Button {
                    Finder.reveal(item.url)
                } label: {
                    Image(systemName: "folder")
                }
                .help("Reveal in Finder")

                Button {
                    store.requestRemoval(of: item)
                } label: {
                    Image(systemName: "trash")
                        .foregroundStyle(.red)
                }
                .help("Delete this item")
            }
            .buttonStyle(.borderless)
            .frame(width: wActions, alignment: .trailing)
        }
        .padding(.horizontal, hInset)
        .padding(.vertical, vPad)
        .contentShape(Rectangle())
        .contextMenu {
            Button("Reveal in Finder") { Finder.reveal(item.url) }
            Button("Open") { Finder.open(item.url) }
            Divider()
            Button("Delete", role: .destructive) { store.requestRemoval(of: item) }
        }
    }
}
