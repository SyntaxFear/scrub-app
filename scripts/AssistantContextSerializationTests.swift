import Foundation

enum TestFailure: Error, CustomStringConvertible {
    case failed(String)

    var description: String {
        switch self {
        case .failed(let message):
            return message
        }
    }
}

struct InstalledApp: Hashable {
    let bundleID: String
    let name: String
    let url: URL
    let version: String
}

enum ItemCategory: Hashable {
    case application
    case preferences
    case caches
    case support
    case logs

    var label: String {
        switch self {
        case .application: "Application"
        case .preferences: "Preferences"
        case .caches: "Caches"
        case .support: "Application Support"
        case .logs: "Logs"
        }
    }
}

enum MatchConfidence {
    case exact
    case likely
}

enum FileDomain {
    case user
    case admin
}

struct RelatedItem: Hashable {
    let url: URL
    let category: ItemCategory
    let confidence: MatchConfidence
    let domain: FileDomain
    var size: Int64
    var apparentSize: Int64
    var vendorShared: Bool

    var displayName: String { url.lastPathComponent }
}

struct OrphanGroup: Hashable {
    let inferredBundleID: String
    let displayName: String
    var items: [RelatedItem]
}

enum CodeSignature {
    static func teamIdentifier(forBundleAt url: URL) -> String? {
        url.pathExtension == "app" ? "TEAM123456" : nil
    }
}

final class AppStore {
    var selectedApp: InstalledApp?
    var selectedOrphan: OrphanGroup?
    var detailItems: [RelatedItem] = []
    var detailSelection: Set<URL> = []
    var isSizingDetail = false

    var selectedItems: [RelatedItem] {
        detailItems.filter { detailSelection.contains($0.url) }
    }
}

@main
struct AssistantContextSerializationTests {
    static func main() throws {
        try testApplicationContextSerialization()
        try testLeftoverContextSerialization()
        try testHugeListIsCappedAndKeepsFocusedItem()
        print("Assistant context serialization tests passed")
    }

    private static func testApplicationContextSerialization() throws {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let appURL = home.appendingPathComponent("Applications/Needle.app")
        let app = InstalledApp(
            bundleID: "com.example.needle",
            name: "Needle",
            url: appURL,
            version: "2.4.1"
        )
        let bundle = item(
            "Applications/Needle.app",
            category: .application,
            confidence: .exact,
            domain: .admin,
            size: 100,
            apparentSize: 120
        )
        let cache = item(
            "Library/Caches/com.example.needle",
            category: .caches,
            confidence: .exact,
            domain: .user,
            size: 40,
            apparentSize: 45
        )
        let shared = item(
            "Library/Group Containers/TEAM123456.shared",
            category: .support,
            confidence: .likely,
            domain: .admin,
            size: 80,
            apparentSize: 90,
            vendorShared: true
        )

        let store = AppStore()
        store.selectedApp = app
        store.detailItems = [bundle, cache, shared]
        store.detailSelection = [bundle.url, shared.url]
        store.isSizingDetail = true

        let context = try require(store.assistantContext(focusedItem: shared), "expected app context")
        let decoded = try roundTrip(context)

        try expect(decoded.target.kind == .application, "target kind should be application")
        try expect(decoded.target.name == "Needle", "target name should serialize")
        try expect(decoded.target.bundleID == "com.example.needle", "bundle ID should serialize")
        try expect(decoded.target.version == "2.4.1", "version should serialize")
        try expect(decoded.target.appPath == "~/Applications/Needle.app", "home path should be redacted")
        try expect(decoded.target.codeSigningTeamID == "TEAM123456", "team ID should serialize when available")
        try expect(decoded.target.selectedCount == 2, "selected count should serialize")
        try expect(decoded.target.isSizing, "sizing state should serialize")

        let focused = try require(decoded.focusedItem, "expected focused item")
        try expect(focused.path == "~/Library/Group Containers/TEAM123456.shared", "focused path should be redacted")
        try expect(focused.category == "Application Support", "category label should serialize")
        try expect(focused.confidence == "likely", "confidence should serialize")
        try expect(focused.domain == "admin", "admin domain should serialize")
        try expect(focused.vendorShared, "vendor-shared flag should serialize")
        try expect(focused.selected, "selected row should serialize")
        try expect(focused.focused, "focused row should serialize")
        try expect(!context.jsonString.contains(NSHomeDirectory()), "raw home path should not appear in JSON")
        try expect(decoded.notes.contains { $0.contains("metadata only") }, "metadata-only notice should serialize")
    }

    private static func testLeftoverContextSerialization() throws {
        let support = item(
            "Library/Application Support/Ghost",
            category: .support,
            confidence: .likely,
            domain: .user,
            size: 25,
            apparentSize: 30
        )
        let preferences = item(
            "Library/Preferences/com.example.ghost.plist",
            category: .preferences,
            confidence: .exact,
            domain: .user,
            size: 5,
            apparentSize: 5
        )

        let store = AppStore()
        store.selectedOrphan = OrphanGroup(
            inferredBundleID: "com.example.ghost",
            displayName: "Ghost",
            items: [support, preferences]
        )
        store.detailItems = [support, preferences]
        store.detailSelection = [support.url, preferences.url]

        let context = try require(store.assistantContext(focusedItem: preferences), "expected leftover context")
        let decoded = try roundTrip(context)

        try expect(decoded.target.kind == .leftover, "target kind should be leftover")
        try expect(decoded.target.inferredBundleID == "com.example.ghost", "leftover bundle ID should serialize")
        try expect(decoded.target.bundleID == nil, "leftovers should not claim an installed bundle ID")
        try expect(decoded.target.appPath == nil, "leftovers should not claim an app path")
        try expect(decoded.target.totalSize == 30, "leftover total size should serialize")
        try expect(decoded.categoryTotals.count == 2, "category totals should serialize")
        try expect(decoded.totalItems == 2, "total item count should serialize")
    }

    private static func testHugeListIsCappedAndKeepsFocusedItem() throws {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        let app = InstalledApp(
            bundleID: "com.example.large",
            name: "Large Scan",
            url: home.appendingPathComponent("Applications/Large Scan.app"),
            version: "1.0"
        )

        let items = (0..<85).map { index in
            item(
                "Library/Caches/com.example.large/item-\(index)",
                category: .caches,
                confidence: .exact,
                domain: .user,
                size: Int64(index),
                apparentSize: Int64(index)
            )
        }
        let focused = items[0]

        let store = AppStore()
        store.selectedApp = app
        store.detailItems = items
        store.detailSelection = Set(items.map(\.url))

        let context = try require(store.assistantContext(focusedItem: focused), "expected capped context")
        let decoded = try roundTrip(context)

        try expect(decoded.totalItems == 85, "full item count should serialize")
        try expect(decoded.itemsIncluded == 60, "included item list should stay capped at 60")
        try expect(decoded.topLargestItems.count == 60, "top-largest list should stay capped at 60")
        try expect(
            decoded.topLargestItems.contains { $0.path.hasSuffix("/item-0") && $0.focused },
            "focused row should be retained even when it is outside the largest items"
        )
        try expect(
            decoded.topLargestItems.contains { $0.path.hasSuffix("/item-84") },
            "largest rows should be retained"
        )
    }

    private static func item(_ relativePath: String,
                             category: ItemCategory,
                             confidence: MatchConfidence,
                             domain: FileDomain,
                             size: Int64,
                             apparentSize: Int64,
                             vendorShared: Bool = false) -> RelatedItem {
        let home = URL(fileURLWithPath: NSHomeDirectory(), isDirectory: true)
        return RelatedItem(
            url: home.appendingPathComponent(relativePath),
            category: category,
            confidence: confidence,
            domain: domain,
            size: size,
            apparentSize: apparentSize,
            vendorShared: vendorShared
        )
    }

    private static func roundTrip(_ context: AssistantContext) throws -> AssistantContext {
        let data = try require(context.jsonString.data(using: .utf8), "expected UTF-8 JSON")
        return try JSONDecoder().decode(AssistantContext.self, from: data)
    }

    private static func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
        guard condition() else { throw TestFailure.failed(message) }
    }

    private static func require<T>(_ value: T?, _ message: String) throws -> T {
        guard let value else { throw TestFailure.failed(message) }
        return value
    }
}
