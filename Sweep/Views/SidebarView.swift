import SwiftUI

struct SidebarView: View {
    @Environment(AppStore.self) private var store

    var body: some View {
        @Bindable var store = store

        VStack(spacing: 0) {
            ModeSwitcher(mode: $store.mode)
                .padding(.horizontal, 12)
                .padding(.top, 10)
                .padding(.bottom, 8)

            Group {
                switch store.mode {
                case .apps:      appList(store)
                case .leftovers: leftoverList(store)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Apps

    @ViewBuilder
    private func appList(_ store: AppStore) -> some View {
        @Bindable var store = store

        if store.isLoadingApps && store.apps.isEmpty {
            ProgressView("Scanning Applications…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            VStack(spacing: 0) {
                SortMenu(field: $store.appSortField, ascending: $store.appSortAscending)
                Divider()
                List(selection: $store.selectedAppID) {
                    Section("Applications") {
                        ForEach(store.filteredApps) { app in
                            AppRow(app: app).tag(app.id)
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: store.selectedAppID) { _, newValue in
                    store.selectApp(newValue)
                }
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
        } else if store.leftovers.isEmpty {
            ContentUnavailableView(
                "No Leftovers Found",
                systemImage: "sparkles",
                description: Text("Files from apps you've already deleted will appear here.")
            )
        } else {
            VStack(spacing: 0) {
                SortMenu(field: $store.appSortField, ascending: $store.appSortAscending)
                Divider()
                List(selection: $store.selectedOrphanID) {
                    Section("From deleted apps") {
                        ForEach(store.filteredLeftovers) { group in
                            LeftoverRow(group: group).tag(group.id)
                        }
                    }
                }
                .listStyle(.sidebar)
                .onChange(of: store.selectedOrphanID) { _, newValue in
                    store.selectOrphan(newValue)
                }
            }
        }
    }
}

private struct ModeSwitcher: View {
    @Binding var mode: AppStore.Mode
    @Namespace private var selection

    var body: some View {
        HStack(spacing: 4) {
            segment(.apps, title: "Applications", systemImage: "square.grid.2x2")
            segment(.leftovers, title: "Leftovers", systemImage: "shippingbox")
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(Color.white.opacity(0.10), lineWidth: 1)
        }
    }

    private func segment(_ value: AppStore.Mode, title: String, systemImage: String) -> some View {
        let selected = mode == value

        return Button {
            withAnimation(.snappy(duration: 0.18)) {
                mode = value
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .imageScale(.small)
                Text(title)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
            }
            .font(.caption.weight(.semibold))
            .foregroundStyle(selected ? Color.primary : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: 24)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(.regularMaterial)
                        .matchedGeometryEffect(id: "selectedMode", in: selection)
                        .shadow(color: Color.black.opacity(0.18), radius: 5, y: 1)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}

/// A compact sort control for the app list: sort by name or size, ascending or
/// descending.
private struct SortMenu: View {
    @Binding var field: AppStore.AppSortField
    @Binding var ascending: Bool

    var body: some View {
        HStack(spacing: 6) {
            Text("Sort").foregroundStyle(.secondary)
            Picker("Sort by", selection: $field) {
                Text("Name").tag(AppStore.AppSortField.name)
                Text("Size").tag(AppStore.AppSortField.size)
            }
            .pickerStyle(.menu)
            .labelsHidden()
            .fixedSize()

            Button {
                ascending.toggle()
            } label: {
                Image(systemName: ascending ? "arrow.up" : "arrow.down")
                    .frame(width: 22, height: 22)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .help(ascending ? "Ascending" : "Descending")
            .accessibilityLabel("Sort direction")
            .accessibilityValue(ascending ? "Ascending" : "Descending")

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 5)
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
            if app.size < 0 {
                ProgressView().controlSize(.mini)
            } else {
                Text(Format.size(app.size))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, 2)
    }
}

private struct LeftoverRow: View {
    let group: OrphanGroup

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: "shippingbox.fill")
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
