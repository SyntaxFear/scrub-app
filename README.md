<p align="center">
  <img src="icon.png" alt="Scrub app icon" width="120" height="120">
</p>

# Scrub

Scrub is a Mac app that helps you uninstall apps completely.

When you delete an app by dragging it to the Trash, macOS often leaves extra
files behind. These files can live in places like Application Support, Caches,
Preferences, Containers, Logs, WebKit data, cookies, and background helper
folders.

Scrub finds those related files, shows them to you in plain language, and lets
you remove them safely.

## What Scrub Does

- Shows the apps installed on your Mac.
- Lets you search, sort, or drag an app into the window.
- Finds files that belong to the selected app.
- Shows how much space those files use.
- Helps clean leftovers from apps you already deleted.
- Moves normal files to the Trash, so you can restore them if needed.
- Clearly warns when something requires an administrator password.

## Why This Is Useful

Deleting an app does not always remove everything it created.

For example, an app may leave behind:

- Settings and preferences
- Cache files
- Background helpers
- Saved app state
- Web data
- Logs
- App containers
- Old files from apps that are no longer installed

Over time, these leftovers can waste space and make your Mac feel cluttered.
Scrub gives you one place to review and remove them.

## How It Works

1. Open Scrub.
2. Sign in with Apple, Google, or email.
3. Scrub scans your Mac for installed apps.
4. Pick an app from the list, search for it, or drag a `.app` file into Scrub.
5. Scrub looks for files related to that app.
6. Review the list before removing anything.
7. Click remove.
8. Scrub moves normal files to the Trash.
9. If system-level files need removal, Scrub asks for your Mac administrator
   password first.

You stay in control the whole time. Scrub shows what it found before it removes
anything.

## What You See Before Removing

Scrub groups related files by type, such as:

- Application
- Application Support
- Preferences
- Caches
- Containers
- Group Containers
- Logs
- WebKit data
- Cookies
- Saved app state
- Launch agents and launch daemons

Some matches are very confident because they use the app's exact bundle
identifier, which is the unique app ID used by macOS. These are selected
automatically.

Some matches are marked as `Likely`. These are possible matches based on the
app name or developer name. Scrub shows them, but leaves them for you to review.

Shared vendor files are also called out, because they may be used by more than
one app from the same developer.

## Leftovers From Deleted Apps

Scrub also has a Leftovers view.

This looks for files that appear to belong to apps that are no longer installed.
It is useful when you already deleted an app in the past and want to clean up
what it left behind.

## Safety

Scrub is designed to be careful.

- Normal user files go to the Trash first.
- You get a final confirmation screen before anything is removed.
- System-level files are shown separately.
- Files that require an administrator password are marked clearly.
- Scrub refuses to remove protected locations like your home folder, `/`,
  `/System`, `/Library`, or top-level folders such as Desktop, Documents, and
  Downloads.
- Name-based matches are treated carefully and marked as `Likely`.

Full Disk Access is recommended so Scrub can see all the places where apps store
their files. Without it, some results may be missing.

## Privacy

Scrub scans your apps and related files on your Mac.

The cleanup scan does not need to upload your app list or file list to a server.
Sign-in uses Scrub's online sign-in service, and your Scrub session token is
stored in the macOS Keychain.

If you connect ChatGPT/Codex and ask the assistant a cleanup question, Scrub sends
metadata only — app names, bundle identifiers, paths, categories, sizes, and match
confidence. File contents are never sent, and the assistant cannot delete anything.

## Extra Features

- Search installed apps.
- Sort apps by name or size.
- Reveal any found file in Finder.
- Quit a running app before removing it.
- Menu bar shortcut for opening Scrub and emptying the Trash.
- Optional launch at login.
- Optional automatic updates.
- "What's New" screen after updates.
- Optional ChatGPT/Codex assistant for read-only cleanup recommendations.

## Important Notes

- Scrub is a powerful Mac utility.
- Review the list before removing files.
- Files moved to the Trash can usually be restored.
- System-level files that require an administrator password may be removed
  permanently.
- Scrub is not intended for the Mac App Store because it needs deeper access to
  clean app files properly.

## Install

If you have a ready-made `Scrub.app`:

1. Move `Scrub.app` to your Applications folder.
2. Open it.
3. If macOS shows a security warning, right-click the app and choose Open.
4. Grant Full Disk Access when Scrub asks for it.

## For Developers

Scrub is built with SwiftUI for macOS 14 or newer.

Open the project in Xcode:

```sh
open Scrub.xcodeproj
```

Then run the `Scrub` scheme.
