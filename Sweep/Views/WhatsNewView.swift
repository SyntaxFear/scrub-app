import SwiftUI
import AppKit

/// A small pill shown by the sidebar toggle after an update. Clicking it opens the
/// "What's New" sheet; the ✕ dismisses it. Either way it clears and won't return
/// until the next update.
struct WhatsNewChip: View {
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 5) {
            Button(action: onOpen) {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                    Text("What’s New")
                }
                .font(.caption.weight(.semibold))
            }
            .buttonStyle(.plain)

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .opacity(0.7)
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(Color.accentColor)
        .padding(.horizontal, 9)
        .padding(.vertical, 4)
        .background(Color.accentColor.opacity(0.15), in: Capsule())
        .help("See what’s new in this version")
    }
}

/// The "What's New" sheet — this version's highlights.
struct WhatsNewView: View {
    let entry: ChangelogEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            VStack(spacing: 10) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 64, height: 64)
                Text("What’s New in Scrub \(entry.version)")
                    .font(.title2.weight(.bold))
            }
            .padding(.top, 30)
            .padding(.bottom, 20)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(entry.highlights, id: \.self) { highlight in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.tint)
                                .font(.body)
                            Text(highlight)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.bottom, 8)
            }

            Divider()
            Button("Continue") { dismiss() }
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
                .padding(16)
        }
        .frame(width: 460, height: 470)
    }
}
