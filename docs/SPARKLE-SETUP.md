# Sparkle auto-update — status

**Integrated and building.** Done in this session:
- Sparkle 2.9.3 added to the Xcode project (via the project file directly) and
  embedded as `Scrub.app/Contents/Frameworks/Sparkle.framework`.
- `UpdaterService` (`#if canImport(Sparkle)`) is now live — checks/downloads per
  the "Automatic updates" setting.
- EdDSA signing key generated; **public** key is in `Info.plist` as `SUPublicEDKey`
  (`U0n4/hIaleCo6/GsLES7Hm0mz2la0AcsYcDO5zZDUn4=`); `SUFeedURL` =
  `https://scrubmac.app/appcast.xml`.
- `release.sh` already signs the DMG + writes/updates the appcast.

## You should do once (important)
**Back up the private signing key.** It currently lives only in your login
Keychain — if you lose it you can't ship signed updates. Export and store it
somewhere safe (password manager / offline), then delete the file:

```
build/dd-debug/SourcePackages/artifacts/sparkle/Sparkle/bin/generate_keys -x sparkle_private_key.txt
# store sparkle_private_key.txt securely, then: rm sparkle_private_key.txt
```

## On the first real release
`release.sh` finds `generate_appcast` automatically when `SPARKLE_BIN` points at
Sparkle's `bin/`:

```
SPARKLE_BIN="$(pwd)/build/dd-debug/SourcePackages/artifacts/sparkle/Sparkle/bin" \
  TEAM_ID=CNH4KYRW44 ./scripts/release.sh
```

It signs the DMG, drops it + `appcast.xml` into `../scrub-site/public/`, then
deploy scrub-site to publish. The only thing that can't be verified from here is a
real old→new update install — do that once with two signed builds.
