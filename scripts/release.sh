#!/usr/bin/env bash
#
# Build, sign, notarize, and package Scrub for distribution outside the App Store.
#
# Prerequisites (one-time):
#   1. A "Developer ID Application" certificate in your login keychain.
#      Create it in Xcode ▸ Settings ▸ Accounts ▸ Manage Certificates ▸ + ,
#      or at https://developer.apple.com/account/resources/certificates
#   2. A stored notarization profile so we never put credentials in this file:
#        xcrun notarytool store-credentials "Scrub" \
#          --apple-id "levan.parastashvili@icloud.com" \
#          --team-id "CNH4KYRW44" \
#          --password "app-specific-password"   # appleid.apple.com ▸ App-Specific Passwords
#
# Usage:
#   TEAM_ID=XXXXXXXXXX ./scripts/release.sh
#
# Optional env overrides:
#   SIGN_IDENTITY   default: "Developer ID Application"  (matched by name)
#   NOTARY_PROFILE  default: "Scrub"
#   SCHEME          default: "Scrub"
#   RELEASE_ENTITLEMENTS default: "Scrub/Distribution.entitlements"

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="${SCHEME:-Scrub}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-Scrub}"
RELEASE_ENTITLEMENTS="${RELEASE_ENTITLEMENTS:-Scrub/Distribution.entitlements}"
: "${TEAM_ID:?Set TEAM_ID to your 10-character Apple Developer Team ID}"

BUILD_DIR="build/release"
ARCHIVE="$BUILD_DIR/Scrub.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/Scrub.app"
VERSIONED_DMG=""
LATEST_DMG="$BUILD_DIR/Scrub.dmg"
MANIFEST_PATH="${MANIFEST_PATH:-Scrub/Releases.json}"
SITE_DIR="${SITE_DIR:-../scrub-site}"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "▸ Archiving (Release, Developer ID, hardened runtime)…"
xcodebuild -project Scrub.xcodeproj -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  CODE_SIGN_ENTITLEMENTS="$RELEASE_ENTITLEMENTS" \
  OTHER_CODE_SIGN_FLAGS="--timestamp" \
  archive

echo "▸ Exporting Developer ID app…"
cat > "$BUILD_DIR/ExportOptions.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key><string>developer-id</string>
    <key>teamID</key><string>${TEAM_ID}</string>
    <key>signingStyle</key><string>manual</string>
</dict>
</plist>
PLIST

xcodebuild -exportArchive -archivePath "$ARCHIVE" \
  -exportOptionsPlist "$BUILD_DIR/ExportOptions.plist" \
  -exportPath "$EXPORT_DIR"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")"
APP_BUILD="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Contents/Info.plist")"
MINIMUM_MACOS="${MINIMUM_MACOS:-14.0}"
VERSIONED_DMG="$BUILD_DIR/Scrub-${APP_VERSION}.dmg"

echo "▸ Packaging DMG…"
hdiutil create -volname "Scrub" -srcfolder "$APP" -ov -format UDZO "$VERSIONED_DMG" >/dev/null

echo "▸ Signing the DMG with Developer ID…"
# Sign the disk image itself (not just the app inside) so Gatekeeper accepts the
# DMG on a direct `spctl --type open` check, in addition to the stapled ticket.
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$VERSIONED_DMG"

echo "▸ Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$VERSIONED_DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Stapling ticket…"
xcrun stapler staple "$VERSIONED_DMG"
xcrun stapler staple "$APP"

echo "▸ Verifying Gatekeeper acceptance…"
# A disk image is assessed with --type open (not --type install, which is for
# installer .pkg files). This should report "accepted / Notarized Developer ID".
spctl -a -t open --context context:primary-signature -vvv "$VERSIONED_DMG"
xcrun stapler validate "$VERSIONED_DMG"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl -a -vvv -t exec "$APP"

cp "$VERSIONED_DMG" "$LATEST_DMG"
DMG_SHA256="$(shasum -a 256 "$VERSIONED_DMG" | awk '{print $1}')"
DMG_SIZE="$(stat -f '%z' "$VERSIONED_DMG")"

echo "▸ Updating release manifest…"
RELEASE_DATE="${RELEASE_DATE:-$(date -u +%F)}" \
APP_VERSION="$APP_VERSION" \
APP_BUILD="$APP_BUILD" \
MINIMUM_MACOS="$MINIMUM_MACOS" \
DMG_SHA256="$DMG_SHA256" \
DMG_SIZE="$DMG_SIZE" \
MANIFEST_PATH="$MANIFEST_PATH" \
node <<'NODE'
const fs = require("node:fs");

const manifestPath = process.env.MANIFEST_PATH;
const version = process.env.APP_VERSION;
const build = process.env.APP_BUILD;
const date = process.env.RELEASE_DATE;
const minimumMacOS = process.env.MINIMUM_MACOS;
const sha256 = process.env.DMG_SHA256;
const fileSize = Number(process.env.DMG_SIZE);

const manifest = JSON.parse(fs.readFileSync(manifestPath, "utf8"));
if (manifest.schemaVersion !== 1 || !Array.isArray(manifest.releases)) {
  throw new Error(`${manifestPath} must be a schemaVersion 1 release manifest`);
}

const release = manifest.releases.find((entry) => entry.version === version);
if (!release) {
  throw new Error(`Add release notes for ${version} to ${manifestPath} before releasing.`);
}
if (!Array.isArray(release.highlights) || release.highlights.length === 0) {
  throw new Error(`Release ${version} needs at least one highlight.`);
}

Object.assign(release, {
  build,
  date,
  minimumMacOS,
  sha256,
  fileSize,
  latestPath: "/Scrub.dmg",
  archivePath: `/releases/Scrub-${version}.dmg`,
});

function versionParts(input) {
  return input.split(".").map((part) => Number.parseInt(part, 10) || 0);
}

manifest.releases.sort((a, b) => {
  const aa = versionParts(a.version);
  const bb = versionParts(b.version);
  for (let i = 0; i < Math.max(aa.length, bb.length); i += 1) {
    const diff = (bb[i] || 0) - (aa[i] || 0);
    if (diff) return diff;
  }
  return Number(b.build || 0) - Number(a.build || 0);
});

fs.writeFileSync(manifestPath, `${JSON.stringify(manifest, null, 2)}\n`);
NODE

echo "▸ Updating Sparkle appcast…"
# generate_appcast ships with the Sparkle package; it reads the private EdDSA key
# from your login Keychain, signs each update, and writes appcast.xml next to the
# DMGs. We host both on scrubmac.app, so we drop them into the site's public/ dir.
# Skipped cleanly until Sparkle is set up (see docs/SPARKLE-SETUP.md).
UPDATES_DIR="${UPDATES_DIR:-$SITE_DIR/public}"
RELEASES_DIR="$UPDATES_DIR/releases"
DOWNLOAD_PREFIX="${DOWNLOAD_PREFIX:-https://scrubmac.app/}"
GENERATE_APPCAST="$(command -v generate_appcast || true)"
if [ -z "$GENERATE_APPCAST" ] && [ -n "${SPARKLE_BIN:-}" ] && [ -x "$SPARKLE_BIN/generate_appcast" ]; then
  GENERATE_APPCAST="$SPARKLE_BIN/generate_appcast"
fi
mkdir -p "$RELEASES_DIR" "$SITE_DIR/src/data"
cp "$VERSIONED_DMG" "$RELEASES_DIR/Scrub-${APP_VERSION}.dmg"
cp "$LATEST_DMG" "$UPDATES_DIR/Scrub.dmg"
cp "$MANIFEST_PATH" "$SITE_DIR/src/data/releases.json"
cp "$MANIFEST_PATH" "$UPDATES_DIR/releases.json"
if [ -n "$GENERATE_APPCAST" ] && [ -x "$GENERATE_APPCAST" ]; then
  APPCAST_INPUT_DIR="$BUILD_DIR/appcast-input"
  rm -rf "$APPCAST_INPUT_DIR"
  mkdir -p "$APPCAST_INPUT_DIR"
  cp "$VERSIONED_DMG" "$APPCAST_INPUT_DIR/Scrub-${APP_VERSION}.dmg"
  "$GENERATE_APPCAST" --download-url-prefix "${DOWNLOAD_PREFIX}releases/" "$APPCAST_INPUT_DIR"
  cp "$APPCAST_INPUT_DIR/appcast.xml" "$UPDATES_DIR/appcast.xml"
  echo "✓ appcast.xml, Scrub.dmg, archived DMG, and releases.json updated in $UPDATES_DIR."
else
  echo "⚠︎ Sparkle's generate_appcast not found; skipping appcast."
  echo "  Set SPARKLE_BIN to Sparkle's bin/ once the package is added (docs/SPARKLE-SETUP.md)."
  echo "✓ Scrub.dmg, archived DMG, and releases.json still updated in $UPDATES_DIR."
fi

echo "✓ Done: $VERSIONED_DMG and $LATEST_DMG"
