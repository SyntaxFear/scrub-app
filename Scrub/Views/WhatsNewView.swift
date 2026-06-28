import SwiftUI
import AppKit

/// A small toolbar accessory shown after an update. Clicking it opens the
/// "What's New" sheet; the x dismisses it. Either way it clears and won't return
/// until the next update.
struct WhatsNewChip: View {
    let onOpen: () -> Void
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Button(action: onOpen) {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .imageScale(.small)
                    Text("What’s New")
                }
                .font(.callout)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 4)
            }
            .buttonStyle(.borderless)
            .controlSize(.regular)
            .accessibilityLabel("What's New")
            .help("See what’s new in this version")

            Button(action: onDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .controlSize(.small)
            .accessibilityLabel("Dismiss What's New")
            .help("Dismiss What's New")
        }
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
            HStack {
                Spacer()
                Button("Continue") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
            .padding(16)
        }
        .frame(width: 460)
        .frame(minHeight: 360, maxHeight: 520)
    }
}
