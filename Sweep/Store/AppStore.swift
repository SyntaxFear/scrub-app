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
    private var leftoverSizeToken = 0
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
        checkWhatsNew()
        Task { await loadApps() }
        // TEMPORARY (user review): always show the "What's New" button in the header so
        // the post-update discovery + open flow can be checked (the user clicks it to
        // open the sheet). Revert to version-gated `checkWhatsNew()` before shipping.
        showWhatsNewChip = true
    }

    // MARK: - What's New

    /// True while the post-update "What's New" chip should show by the sidebar toggle.
    /// TEMPORARY (user review): defaulted ON so the header button reliably shows even
    /// when macOS restores the window without re-running launch logic. Revert to
    /// `false` (version-gated) when fixing the What's New logic for production.
    var showWhatsNewChip = true
    /// Drives the "What's New" sheet.
    var showingWhatsNew = false

    /// On launch, show the chip when the running version differs from the last one
    /// the user saw. The very first install just records the version silently.
    private func checkWhatsNew() {
        let current = Preferences.currentVersion
        let haveNotesForCurrent = Changelog.entries.contains { $0.version == current }
        if let last = Preferences.lastSeenVersion {
            showWhatsNewChip = (last != current) && haveNotesForCurrent
        } else {
            Preferences.lastSeenVersion = current
        }
    }

    func openWhatsNew() {
        showingWhatsNew = true
        dismissWhatsNewChip()
    }

    func dismissWhatsNewChip() {
        showWhatsNewChip = false
        Preferences.lastSeenVersion = Preferences.currentVersion
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
        await withTaskGroup(of: (InstalledApp.ID, Int64, Int64).self) { group in
            let maxConcurrent = 6
            var next = 0
            func addTask() {
                guard next < discovered.count else { return }
                let app = discovered[next]
                next += 1
                group.addTask(priority: .utility) {
                    let f = AppScanner.footprint(of: app)
                    return (app.id, f.onDisk, f.apparent)
                }
            }
            for _ in 0..<maxConcurrent { addTask() }

            for await (id, onDisk, apparent) in group {
                if token != appLoadToken { group.cancelAll(); return }
                if let idx = apps.firstIndex(where: { $0.id == id }) {
                    apps[idx].size = onDisk
                    apps[idx].apparentSize = apparent
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

    /// The items checked by default when an app is selected.
    ///
    /// Exact (bundle-ID) matches are always trusted. App-specific name- and
    /// bundle-ID matches (`.likely`, not `vendorShared`) are trusted too — but
    /// only once the app's identity is *corroborated* by an exact support-file
    /// match, i.e. independent proof that this bundle ID really owns data on
    /// disk. With that proof, a folder named after the same app — like an
    /// Electron app's multi-gigabyte `Application Support/<Name>` (named after
    /// the display name, not the bundle ID) — is almost certainly its data, so
    /// it's selected for a *complete* uninstall instead of being silently left
    /// behind. Two cases stay unchecked for the user to confirm: matches with no
    /// corroboration (pure name guesses), and `vendorShared` Team-ID folders
    /// that sibling apps from the same developer may also use.
    static func defaultSelection(for items: [RelatedItem]) -> Set<URL> {
        let identityConfirmed = items.contains {
            $0.confidence == .exact && $0.category != .application
        }
        return Set(
            items
                .filter { item in
                    if item.confidence == .exact { return true }
                    return identityConfirmed && !item.vendorShared
                }
                .map(\.url)
        )
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
            detailSelection = Self.defaultSelection(for: items)
            isScanningDetail = false
            isSizingDetail = true

            // Measure each item concurrently, applying every result to its row the
            // moment it lands. A single huge folder (a multi-GB cache, say) then only
            // keeps its own row spinning instead of blocking the entire table.
            await measureDetailSizes(token: token)
        }
    }

    /// Sizes the current `detailItems` with bounded concurrency, merging each result
    /// in as it completes so rows fill progressively rather than all-at-once.
    private func measureDetailSizes(token: Int) async {
        let urls = detailItems.map(\.url)
        await withTaskGroup(of: (URL, Int64, Int64).self) { group in
            let maxConcurrent = 6
            var next = 0
            func addTask() {
                guard next < urls.count else { return }
                let url = urls[next]
                next += 1
                group.addTask(priority: .utility) {
                    let m = FileSystem.measure(of: url)
                    return (url, m.onDisk, m.apparent)
                }
            }
            for _ in 0..<maxConcurrent { addTask() }

            for await (url, onDisk, apparent) in group {
                if token != detailScanToken { group.cancelAll(); return }
                if let idx = detailItems.firstIndex(where: { $0.url == url }) {
                    detailItems[idx].size = onDisk
                    detailItems[idx].apparentSize = apparent
                }
                addTask()
            }
        }
        guard token == detailScanToken else { return }
        isSizingDetail = false
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
        hasScannedLeftovers = true
        leftoverSizeToken += 1
        let token = leftoverSizeToken

        let installed = apps
        // Phase 1: scan only (fast — just enumerating folders). Show the list right
        // away instead of blocking on measuring every leftover folder first.
        let groups = await Task.detached(priority: .userInitiated) {
            OrphanScanner.scan(installed: installed)
        }.value
        leftovers = groups
        isScanningLeftovers = false
        if selectedOrphanID == nil { selectedOrphanID = groups.first?.id }
        if let id = selectedOrphanID { selectOrphan(id) }

        // Phase 2: measure every leftover concurrently, merging each size in as it
        // lands, so group totals and the detail rows fill in progressively.
        await sizeLeftovers(token: token)
    }

    private func sizeLeftovers(token: Int) async {
        let urls = leftovers.flatMap { $0.items.map(\.url) }
        await withTaskGroup(of: (URL, Int64, Int64).self) { group in
            let maxConcurrent = 6
            var next = 0
            func addTask() {
                guard next < urls.count else { return }
                let url = urls[next]
                next += 1
                group.addTask(priority: .utility) {
                    let m = FileSystem.measure(of: url)
                    return (url, m.onDisk, m.apparent)
                }
            }
            for _ in 0..<maxConcurrent { addTask() }

            for await (url, onDisk, apparent) in group {
                if token != leftoverSizeToken { group.cancelAll(); return }
                applyLeftoverSize(url: url, onDisk: onDisk, apparent: apparent)
                addTask()
            }
        }
    }

    /// Merges a measured size into the matching leftover item — and into the live
    /// detail list too if that item's group is the one currently on screen.
    private func applyLeftoverSize(url: URL, onDisk: Int64, apparent: Int64) {
        for gi in leftovers.indices {
            if let ii = leftovers[gi].items.firstIndex(where: { $0.url == url }) {
                leftovers[gi].items[ii].size = onDisk
                leftovers[gi].items[ii].apparentSize = apparent
                break
            }
        }
        if selectedOrphanID != nil, let di = detailItems.firstIndex(where: { $0.url == url }) {
            detailItems[di].size = onDisk
            detailItems[di].apparentSize = apparent
        }
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

    /// Requests removal of an explicit set of items (the multi-row context-menu
    /// action), independent of the checkbox selection — so a highlight-driven delete
    /// never clobbers what the user has ticked. Still gated by the confirmation sheet.
    func requestRemoval(of items: [RelatedItem]) {
        guard !items.isEmpty else { return }
        pendingRemoval = items
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
            // Reselect (not just reassign the id) so the detail pane refreshes to
            // the newly-focused group instead of showing the removed one's items.
            if selectedOrphan == nil { selectOrphan(leftovers.first?.id) }
        }
    }
}
