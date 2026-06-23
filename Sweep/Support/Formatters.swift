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
}
