import SwiftUI
import AppKit

/// Renders the Finder icon for a file URL. Icons come from `NSWorkspace`, which
/// caches them, so this stays cheap even in a long list.
struct AppIconView: View {
    let url: URL
    var size: CGFloat = 18

    var body: some View {
        Image(nsImage: NSWorkspace.shared.icon(forFile: url.path))
            .resizable()
            .interpolation(.high)
            .frame(width: size, height: size)
    }
}

/// A category glyph used for support-file rows that have no file icon of note.
struct CategoryGlyph: View {
    let category: ItemCategory
    var body: some View {
        Image(systemName: category.systemImage)
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            .frame(width: 18, height: 18)
    }
}
