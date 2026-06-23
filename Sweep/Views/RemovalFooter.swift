import SwiftUI

/// Bottom action bar: selection summary on the left, the remove button on the
/// right. Lives in a `.bar` material so it reads as a native toolbar.
struct RemovalFooter: View {
    @Environment(AppStore.self) private var store

    private var selectedCount: Int { store.selectedItems.count }
    private var allSelected: Bool {
        !store.detailItems.isEmpty && selectedCount == store.detailItems.count
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(allSelected ? "Deselect All" : "Select All") {
                if allSelected { store.deselectAllItems() } else { store.selectAllItems() }
            }
            .buttonStyle(.link)
            .disabled(store.detailItems.isEmpty)

            Text("\(selectedCount) of \(store.detailItems.count) selected  ·  \(Format.size(store.selectedTotalSize))")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()

            Spacer()

            if store.hasAdminItemsSelected {
                Label("Admin password required", systemImage: "lock.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            Button {
                store.requestRemoval()
            } label: {
                Label(buttonTitle, systemImage: "trash")
                    .padding(.horizontal, 4)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
            .keyboardShortcut(.delete, modifiers: .command)
            .disabled(selectedCount == 0 || store.isRemoving)

            if store.isRemoving {
                ProgressView().controlSize(.small)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.bar)
    }

    private var buttonTitle: String {
        store.hasAdminItemsSelected ? "Remove…" : "Move to Trash"
    }
}
