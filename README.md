# Sweep

A native macOS app uninstaller. Browse your installed apps (or drag one onto the
window), see **every** related file an app has scattered across `~/Library`, and
remove the lot — with your files going safely to the Trash.

Built with SwiftUI for macOS 14+. Personal, non-sandboxed, full-power tool.

![Finder-style table layout]

## Features

- **Browse + drag-and-drop** — pick an app from the sidebar, or drop a `.app` onto the window.
- **Deep leftover scan** — finds Application Support, Caches, Preferences, Containers,
  Group Containers, Saved State, Logs, WebKit, HTTP storage, cookies, and app scripts.
- **Confidence tiers** — files matched by *bundle identifier* are checked by default;
  files matched only by *name* are shown but left for you to confirm (`likely` badge).
- **Orphaned leftovers** — a second tab that hunts down files belonging to apps you've
  already deleted (Apple's own files are excluded).
- **Quit running apps** — if the app is open, it's quit (gracefully, then forced) before removal.
- **Login items, launch agents & daemons** — surfaces and removes `LaunchAgents`/`LaunchDaemons`.
- **Safe by default** — your files go to the **Trash** (reversible). System-level items that
  can't be trashed are removed permanently via a single authenticated prompt, clearly flagged.
- **Full Disk Access aware** — prompts you to grant it so scans are complete.

## Build & run

Open in Xcode:

```sh
open Sweep.xcodeproj
```

Then press ⌘R. Or from the command line:

```sh
xcodebuild -project Sweep.xcodeproj -scheme Sweep -configuration Debug \
  -derivedDataPath build build
open build/Build/Products/Debug/Scrub.app
```

### First run

1. macOS may warn it's from an unidentified developer (the build is ad-hoc signed).
   Right-click the app → **Open**, or allow it in System Settings → Privacy & Security.
2. Grant **Full Disk Access** when prompted (the in-app banner links straight to the
   right Settings pane) so the scan can see every app's data.

## Architecture

```
Sweep/
├── SweepApp.swift              App entry point, window, ⌘R refresh
├── Models/                     Value types — InstalledApp, RelatedItem, OrphanGroup, enums
├── Services/                   Stateless engines (run off the main actor)
│   ├── AppScanner.swift          Discover installed apps + sizes
│   ├── LeftoverScanner.swift     Find an app's related files (exact + likely tiers)
│   ├── OrphanScanner.swift       Find leftovers from deleted apps
│   ├── Remover.swift             Trash user files / privileged-remove admin files
│   ├── RunningAppMonitor.swift   Quit a running app before removal
│   └── FullDiskAccess.swift      Detect & deep-link the permission
├── Store/AppStore.swift        @Observable @MainActor orchestrator + UI state
├── Support/                    FileSystem helpers, byte formatting, SafetyGuard
└── Views/                      SwiftUI — split view, sidebar, Finder-style table, sheets
```

**Safety:** every path passes `SafetyGuard.validate` before deletion — it refuses `/`,
home, and top-level Library folders, and only permits paths under known app roots.

## Notes & limits (v1)

- Non-sandboxed by design; not intended for the Mac App Store.
- Name-based matches are heuristic — that's why they're surfaced as `likely` and left
  unchecked. Review before removing.
- Privileged removals use an authenticated `rm` (one password prompt per batch). A
  future hardening could move this to an `SMAppService` privileged helper.
