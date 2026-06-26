#!/usr/bin/env bash
#
# Build, sign, notarize, and package Sweep for distribution outside the App Store.
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
#   NOTARY_PROFILE  default: "Sweep"
#   SCHEME          default: "Sweep"

set -euo pipefail

cd "$(dirname "$0")/.."

SCHEME="${SCHEME:-Sweep}"
SIGN_IDENTITY="${SIGN_IDENTITY:-Developer ID Application}"
NOTARY_PROFILE="${NOTARY_PROFILE:-Scrub}"
: "${TEAM_ID:?Set TEAM_ID to your 10-character Apple Developer Team ID}"

BUILD_DIR="build/release"
# Xcode project/scheme are named "Sweep", but the product is "Scrub"
# (PRODUCT_NAME = Scrub), so the exported app and DMG are named Scrub.
ARCHIVE="$BUILD_DIR/Scrub.xcarchive"
EXPORT_DIR="$BUILD_DIR/export"
APP="$EXPORT_DIR/Scrub.app"
DMG="$BUILD_DIR/Scrub.dmg"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "▸ Archiving (Release, Developer ID, hardened runtime)…"
xcodebuild -project Sweep.xcodeproj -scheme "$SCHEME" -configuration Release \
  -archivePath "$ARCHIVE" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGN_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
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

echo "▸ Packaging DMG…"
hdiutil create -volname "Scrub" -srcfolder "$APP" -ov -format UDZO "$DMG" >/dev/null

echo "▸ Signing the DMG with Developer ID…"
# Sign the disk image itself (not just the app inside) so Gatekeeper accepts the
# DMG on a direct `spctl --type open` check, in addition to the stapled ticket.
codesign --force --sign "$SIGN_IDENTITY" --timestamp "$DMG"

echo "▸ Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$DMG" --keychain-profile "$NOTARY_PROFILE" --wait

echo "▸ Stapling ticket…"
xcrun stapler staple "$DMG"
xcrun stapler staple "$APP"

echo "▸ Verifying Gatekeeper acceptance…"
# A disk image is assessed with --type open (not --type install, which is for
# installer .pkg files). This should report "accepted / Notarized Developer ID".
spctl -a -t open --context context:primary-signature -vvv "$DMG"
xcrun stapler validate "$DMG"
codesign --verify --deep --strict --verbose=2 "$APP"
spctl -a -vvv -t exec "$APP"

echo "✓ Done: $DMG"
