import SwiftUI

/// Final review before removal. Separates reversible (Trash) items from
/// permanent admin removals so the consequences are explicit.
struct RemovalConfirmationSheet: View {
    @Environment(AppStore.self) private var store

    private var trashItems: [RelatedItem] {
        store.pendingRemoval.filter { $0.domain == .user && FileSystem.isUserDeletable($0.url) }
    }
    private var permanentItems: [RelatedItem] {
        store.pendingRemoval.filter { $0.domain == .admin || !FileSystem.isUserDeletable($0.url) }
    }
    private var totalSize: Int64 {
        store.pendingRemoval.reduce(0) { $0 + max(0, $1.size) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !trashItems.isEmpty {
                        section(
                            title: "Move to Trash",
                            subtitle: "Reversible — you can restore these from the Trash.",
                            symbol: "trash",
                            tint: .secondary,
                            items: trashItems
                        )
                    }
                    if !permanentItems.isEmpty {
                        section(
                            title: "Remove permanently (requires password)",
                            subtitle: "System-level items can't go to the Trash and will be deleted for good.",
                            symbol: "lock.fill",
                            tint: .orange,
                            items: permanentItems
                        )
                    }
                }
                .padding(20)
            }
            .frame(maxHeight: 360)

            Divider()
            footer
        }
        .frame(width: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Remove \(store.pendingRemoval.count) item\(store.pendingRemoval.count == 1 ? "" : "s")?")
                .font(.title3.weight(.semibold))
            Text("Freeing up about \(Format.size(totalSize)).")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(20)
    }

    private func section(title: String, subtitle: String, symbol: String,
                         tint: Color, items: [RelatedItem]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: symbol)
                .font(.headline)
                .foregroundStyle(tint == .secondary ? .primary : tint)
            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
            VStack(spacing: 0) {
                ForEach(items) { item in
                    HStack(spacing: 8) {
                        CategoryGlyph(category: item.category)
                        Text(item.abbreviatedPath)
                            .font(.callout)
                            .lineLimit(1)
                            .truncationMode(.middle)
                        Spacer()
                        Text(Format.size(item.size))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    .padding(.vertical, 5)
                    .padding(.horizontal, 10)
                    if item.id != items.last?.id { Divider() }
                }
            }
            .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) { store.cancelRemoval() }
                .keyboardShortcut(.cancelAction)
            Button(permanentItems.isEmpty ? "Move to Trash" : "Remove") {
                Task { await store.confirmRemoval() }
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(16)
    }
}
