# Sparkle auto-update — finishing setup

All the code and the release pipeline are already in place. `UpdaterService`
activates automatically via `#if canImport(Sparkle)` the moment the package is
linked; `release.sh` already signs + writes the appcast (it skips cleanly until
the tools exist). What's left are a few steps that need Xcode and a signing key.

## 1. Add the Sparkle package (Xcode, ~1 min)
Xcode → File → Add Package Dependencies… →
`https://github.com/sparkle-project/Sparkle` → Up to Next Major, 2.6.0 →
add the **Sparkle** library to the **Sweep** target.

This makes `canImport(Sparkle)` true, so `UpdaterService` starts using Sparkle.

## 2. Generate the EdDSA signing key (one-time)
After the package resolves, run its tool (path under DerivedData
`SourcePackages/checkouts/Sparkle/bin`, or download the Sparkle release):

```
./bin/generate_keys
```

It stores the **private** key in your login Keychain and prints the **public**
key. Keep the private key safe — back it up offline alongside your Apple
Developer ID. Anyone with it can ship updates to all users.

Export a backup: `./bin/generate_keys -x sparkle_private_key.txt` (then store it
somewhere safe and delete the file from disk).

## 3. Add Info.plist keys
The app uses a generated Info.plist. Add these keys (via an `Info.plist` file set
as `INFOPLIST_FILE`, or the target's Info tab):

- `SUFeedURL` = `https://scrubmac.app/appcast.xml`
- `SUPublicEDKey` = the public key printed in step 2
- `SUEnableInstallerLauncherService` = `YES` (hardened-runtime helper)

(The feed URL can alternatively be provided in code; the public key must be in
Info.plist by Sparkle's design.)

## 4. Point the release script at the tools
`release.sh` finds `generate_appcast` on `PATH`, or via `SPARKLE_BIN`:

```
SPARKLE_BIN=/path/to/Sparkle/bin TEAM_ID=CNH4KYRW44 ./scripts/release.sh
```

It signs the DMG, drops it + `appcast.xml` into `../scrub-site/public/`, with
download URLs under `https://scrubmac.app/`. Deploy scrub-site to publish.

## 5. Test the update (needs a real before/after)
Build version 1.1, install it, then release 1.2 and confirm 1.1 offers the update
and installs it on relaunch. This is the only part that can't be verified from
code alone.
