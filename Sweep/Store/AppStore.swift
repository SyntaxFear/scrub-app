import SwiftUI
import Observation

/// Central state and orchestration for the app. Everything the UI reads or acts
/// on flows through here. Heavy file IO is dispatched to background tasks; all
/// published state is mutated back on the main actor.
@MainActor
@Observable
final class AppStore {

    enum Mode: Hashable { case apps, leftovers }
    enum AppSortField: Hashable { case name, size }

    // MARK: - Navigation & search
    var mode: Mode = .apps
    var searchText: String = ""

    // MARK: - Sidebar sorting
    var appSortField: AppSortField = .name
    var appSortAscending = true

    // MARK: - Apps
    private(set) var apps: [InstalledApp] = []
    private(set) var isLoadingApps = false
    var selectedAppID: InstalledApp.ID?
    private var appLoadToken = 0

    // MARK: - Leftovers
    private(set) var leftovers: [OrphanGroup] = []
    private(set) var isScanningLeftovers = false
    private var hasScannedLeftovers = false
    var selectedOrphanID: OrphanGroup.ID?

    // MARK: - Detail (shared by both modes)
    private(set) var detailItems: [RelatedItem] = []
    var detailSelection: Set<URL> = []
    private(set) var isScanningDetail = false
    /// True while folder sizes are still being measured in the background. Drives
    /// the loading indicators on rows and the selection total.
    private(set) var isSizingDetail = false
    private var detailScanToken = 0

    // MARK: - Removal flow
    var pendingRemoval: [RelatedItem] = []
    var showingConfirmation = false
    var isRemoving = false
    var lastOutcome: Remover.Outcome?
    var showingOutcome = false

    // MARK: - Environment
    private(set) var fullDiskAccessGranted = true
    /// True once the user has opened System Settings to grant access. Used to
    /// surface the "Quit & Reopen" prompt, since a grant only applies on relaunch.
    private(set) var didRequestFullDiskAccess = false

    // MARK: - Derived

    var selectedApp: InstalledApp? {
        apps.first { $0.id == selectedAppID }
    }

    var selectedOrphan: OrphanGroup? {
        leftovers.first { $0.id == selectedOrphanID }
    }

    var filteredApps: [InstalledApp] {
        let base = searchText.isEmpty ? apps : apps.filter {
            $0.name.localizedCaseInsensitiveContains(searchText)
            || $0.bundleID.localizedCaseInsensitiveContains(searchText)
        }
        let sorted: [InstalledApp]
        switch appSortField {
        case .name:
            sorted = base.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        case .size:
            // Unknown sizes (-1) sort as smallest so they sink to the bottom
            // while still being computed.
            sorted = base.sorted { max(0, $0.size) < max(0, $1.size) }
        }
        return appSortAscending ? sorted : sorted.reversed()
    }

    var filteredLeftovers: [OrphanGroup] {
        let base = searchText.isEmpty ? leftovers : leftovers.filter {
            $0.displayName.localizedCaseInsensitiveContains(searchText)
            || $0.inferredBundleID.localizedCaseInsensitiveContains(searchText)
        }
        let sorted: [OrphanGroup]
        switch appSortField {
        case .name:
            sorted = base.sorted { $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending }
        case .size:
            sorted = base.sorted { $0.totalSize < $1.totalSize }
        }
        return appSortAscending ? sorted : sorted.reversed()
    }

    var selectedItems: [RelatedItem] {
        detailItems.filter { detailSelection.contains($0.url) }
    }

    var selectedTotalSize: Int64 {
        selectedItems.reduce(0) { $0 + max(0, $1.size) }
    }

    var hasAdminItemsSelected: Bool {
        selectedItems.contains { $0.domain == .admin }
    }

    var isSelectedAppRunning: Bool {
        guard let app = selectedApp else { return false }
        return RunningAppMonitor.isRunning(app)
    }

    // MARK: - Lifecycle

    func start() {
        fullDiskAccessGranted = FullDiskAccess.isGranted()
        Task { await loadApps() }
    }

    /// Re-probes Full Disk Access. Note this can only flip to `true` in a process
    /// that was launched *after* the grant was given (see `FullDiskAccess`).
    func refreshFullDiskAccess() {
        fullDiskAccessGranted = FullDiskAccess.isGranted()
    }

    /// Opens System Settings at Full Disk Access and remembers that we asked, so
    /// the banner can offer the relaunch that actually applies the grant.
    @MainActor
    func openFullDiskAccessSettings() {
        didRequestFullDiskAccess = true
        FullDiskAccess.openSettings()
    }

    // MARK: - App loading

    func loadApps() async {
        appLoadToken += 1
        let token = appLoadToken
        isLoadingApps = true

        let discovered = await Task.detached(priority: .userInitiated) {
            AppScanner.discover()
        }.value
        guard token == appLoadToken else { return }
        apps = discovered
        isLoadingApps = false

        // Phase 2: compute each app's full footprint (bundle + all related files)
        // in the background, applying each result as it lands so the sidebar
        // fills in progressively. Bounded concurrency keeps the UI responsive
        // without hammering the disk with dozens of parallel directory walks.
        await withTaskGroup(of: (InstalledApp.ID, Int64).self) { group in
            let maxConcurrent = 4
            var next = 0
            func addTask() {
                guard next < discovered.count else { return }
                let app = discovered[next]
                next += 1
                group.addTask(priority: .utility) { (app.id, AppScanner.footprint(of: app)) }
            }
            for _ in 0..<maxConcurrent { addTask() }

            for await (id, size) in group {
                if token != appLoadToken { group.cancelAll(); return }
                if let idx = apps.firstIndex(where: { $0.id == id }) {
                    apps[idx].size = size
                }
                addTask()
            }
        }
    }

    // MARK: - Selection

    func selectApp(_ id: InstalledApp.ID?) {
        selectedAppID = id
        selectedOrphanID = nil
        guard let app = apps.first(where: { $0.id == id }) else {
            detailItems = []
            detailSelection = []
            return
        }
        scanDetail(for: app)
    }

    func selectOrphan(_ id: OrphanGroup.ID?) {
        selectedOrphanID = id
        selectedAppID = nil
        guard let group = leftovers.first(where: { $0.id == id }) else {
            detailItems = []
            detailSelection = []
            return
        }
        detailItems = group.items.sorted(by: LeftoverScanner.ordering)
        detailSelection = Set(group.items.map(\.url))   // leftovers default to all selected
        isScanningDetail = false
        isSizingDetail = false
    }

    private func scanDetail(for app: InstalledApp) {
        detailScanToken += 1
        let token = detailScanToken
        isScanningDetail = true
        isSizingDetail = false
        detailItems = []
        detailSelection = []

        Task {
            let items = await Task.detached(priority: .userInitiated) {
                LeftoverScanner.scan(app: app)
            }.value
            guard token == detailScanToken else { return }

            detailItems = items
            // Exact matches are checked by default; likely matches are left off.
            detailSelection = Set(items.filter { $0.confidence == .exact }.map(\.url))
            isScanningDetail = false
            isSizingDetail = true

            // Compute sizes in the background and merge in.
            let sized = await Task.detached(priority: .utility) {
                items.map { item -> RelatedItem in
                    var copy = item
                    copy.size = FileSystem.size(of: item.url)
                    return copy
                }
            }.value
            guard token == detailScanToken else { return }
            detailItems = sized.sorted(by: LeftoverScanner.ordering)
            isSizingDetail = false
        }
    }

    // MARK: - Drag & drop

    /// Resolves dropped file URLs to apps and selects the first one.
    func handleDrop(urls: [URL]) {
        let appURLs = urls.filter { $0.pathExtension == "app" }
        guard let first = appURLs.first else { return }

        mode = .apps
        if let existing = apps.first(where: { $0.url.standardizedFileURL == first.standardizedFileURL }) {
            selectApp(existing.id)
            return
        }
        guard let app = AppScanner.makeApp(from: first) else { return }
        apps.append(app)
        apps.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        selectApp(app.id)
    }

    // MARK: - Detail selection helpers

    func toggleItem(_ url: URL) {
        if detailSelection.contains(url) { detailSelection.remove(url) }
        else { detailSelection.insert(url) }
    }

    func setItem(_ url: URL, selected: Bool) {
        if selected { detailSelection.insert(url) } else { detailSelection.remove(url) }
    }

    func selectAllItems() { detailSelection = Set(detailItems.map(\.url)) }
    func deselectAllItems() { detailSelection.removeAll() }

    // MARK: - Leftovers

    func enterLeftoversMode() {
        mode = .leftovers
        if !hasScannedLeftovers { Task { await refreshLeftovers() } }
    }

    func refreshLeftovers() async {
        isScanningLeftovers = true
        defer { isScanningLeftovers = false }
        hasScannedLeftovers = true

        let installed = apps
        let groups = await Task.detached(priority: .userInitiated) { () -> [OrphanGroup] in
            let raw = OrphanScanner.scan(installed: installed)
            return raw.map { group in
                var copy = group
                copy.items = group.items.map { item in
                    var i = item
                    i.size = FileSystem.size(of: item.url)
                    return i
                }
                return copy
            }
        }.value

        leftovers = groups
        if selectedOrphanID == nil { selectedOrphanID = groups.first?.id }
        if let id = selectedOrphanID { selectOrphan(id) }
    }

    // MARK: - Removal

    func requestRemoval() {
        let items = selectedItems
        guard !items.isEmpty else { return }
        pendingRemoval = items
        showingConfirmation = true
    }

    /// Requests removal of a single item directly (the per-row trash action),
    /// independent of the current selection. Still routed through the
    /// confirmation sheet so the consequences stay explicit.
    func requestRemoval(of item: RelatedItem) {
        pendingRemoval = [item]
        showingConfirmation = true
    }

    func cancelRemoval() {
        showingConfirmation = false
        pendingRemoval = []
    }

    func confirmRemoval() async {
        showingConfirmation = false
        isRemoving = true
        defer { isRemoving = false }

        let items = pendingRemoval
        pendingRemoval = []

        // Quit the app first if it's the one being removed and it's running.
        if let app = selectedApp,
           items.contains(where: { $0.url.standardizedFileURL == app.url.standardizedFileURL }),
           RunningAppMonitor.isRunning(app) {
            _ = await RunningAppMonitor.quit(app)
        }

        let outcome = Remover.remove(items)
        lastOutcome = outcome
        showingOutcome = true

        applyRemoval(of: Set(outcome.trashed + outcome.removedWithAdmin))
    }

    /// Prunes removed URLs from all in-memory state.
    private func applyRemoval(of removed: Set<URL>) {
        guard !removed.isEmpty else { return }

        let standardizedRemoved = Set(removed.map(\.standardizedFileURL))
        func wasRemoved(_ url: URL) -> Bool {
            standardizedRemoved.contains(url.standardizedFileURL)
        }

        detailItems.removeAll { wasRemoved($0.url) }
        detailSelection = detailSelection.filter { !wasRemoved($0) }

        // If the app's own bundle was removed, treat it as fully uninstalled.
        if let app = selectedApp, wasRemoved(app.url) {
            selectedAppID = nil
            detailItems = []
            detailSelection = []
            Task { await loadApps() }
        }

        // Prune leftovers groups.
        if mode == .leftovers {
            leftovers = leftovers.compactMap { group in
                var copy = group
                copy.items.removeAll { wasRemoved($0.url) }
                return copy.items.isEmpty ? nil : copy
            }
            if selectedOrphan == nil { selectedOrphanID = leftovers.first?.id }
        }
    }
}
