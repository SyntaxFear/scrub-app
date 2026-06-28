import Foundation

enum Format {
    private static let byteFormatter: ByteCountFormatter = {
        let f = ByteCountFormatter()
        f.countStyle = .file
        f.allowsNonnumericFormatting = true
        return f
    }()

    /// Human-readable size. A negative value renders as an em dash (not yet known).
    static func size(_ bytes: Int64) -> String {
        guard bytes >= 0 else { return "—" }
        return byteFormatter.string(fromByteCount: bytes)
    }

    /// Bytes below which an apparent-vs-on-disk gap is treated as block-rounding
    /// noise rather than a real sparse gap worth surfacing.
    private static let sparseHintThreshold: Int64 = 50 * 1024 * 1024  // 50 MB

    /// When the apparent (logical) size meaningfully exceeds the on-disk size — the
    /// hallmark of sparse files like VM images — returns a short "X listed" hint to
    /// show next to the real on-disk size. Returns nil when there's nothing to clarify.
    static func listedHint(onDisk: Int64, apparent: Int64) -> String? {
        guard onDisk >= 0, apparent > onDisk,
              apparent - onDisk >= sparseHintThreshold else { return nil }
        return "\(size(apparent)) listed"
    }
}
