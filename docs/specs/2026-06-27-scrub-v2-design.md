# Scrub v2 — Accounts, Auto-update, Menu Bar, Settings

Date: 2026-06-27
Status: Draft for approval

## Goal

Take Scrub from a single-window utility to a complete, production-ready Mac app:
in-app accounts (required), auto-updates, a settings window, a menu bar item, a
"What's New" changelog, and accurate sparse-aware sizes. The marketing site
becomes download-only. Build everything in one pass, then verify with a
3-subagent loop until a clean cycle.

## Decisions (from Q&A)

- **Auth methods:** Sign in with Apple + Google + Email — native, **required** to
  use the app (auth wall on first launch).
- **Website:** download-only. Remove sign-in **and** the email box. Rewrite the
  "no account / nothing leaves your Mac" copy so it's honest.
- **Updates:** Sparkle. Auto-download + "Restart to update" prompt. Feed + DMGs
  on scrubmac.app. I generate the EdDSA signing key (kept safe like the Apple key).
- **What's New:** a chip near the sidebar toggle after an update; persists until
  opened or dismissed; opens a What's New sheet.
- **Settings (⌘,):** Launch at login · Show menu bar icon · Automatic updates ·
  "listed" size hint. **All four default ON.**
- **Menu bar:** optional icon (default ON), Scrub stays a normal Dock app.
  Actions: Empty Trash (with confirm) · Check for updates · Open/Scan · Settings & Quit.
- **Size:** keep real **on-disk** size as the primary number everywhere; show the
  **listed** (apparent) size as a hint only when they differ (sparse files).
- **Verification:** 3 subagents review every feature for production-readiness;
  all 3 must pass; any finding → fix all → fresh 3 → repeat until a clean cycle.

## Architecture

### 1. Settings window
SwiftUI `Settings` scene → standard ⌘, window. Two tabs:
- **General:** Launch at login, Show menu bar icon, Show size hint.
- **Updates:** Automatic updates toggle, "Check Now", current version + last-checked.
Preferences stored in `@AppStorage`/`UserDefaults`, read by the relevant services.

### 2. Launch at login
`SMAppService.mainApp` (macOS 13+; app targets 14+). Toggle registers/unregisters.
Default ON → registered on first run (macOS shows its own "added to login items"
notice, which is expected and honest).

### 3. Menu bar extra
SwiftUI `MenuBarExtra`, `.menu` style, gated by the "Show menu bar icon" setting
via its `isInserted` binding. Actions:
- **Empty Trash** — confirm sheet first (permanent); empties `~/.Trash` via FileManager.
- **Check for updates** — calls Sparkle.
- **Open / Scan now** — activates main window, triggers a scan.
- **Settings… / Quit Scrub.**

### 4. Sparse-aware size
Extend `FileSystem` to compute **both** allocated (on-disk) and logical (apparent)
in a single enumerator pass (two accumulators: `totalFileAllocatedSize` and
`fileSize`). `RelatedItem`/`InstalledApp` carry both. UI shows on-disk as the main
number; when `apparent > onDisk` by a meaningful margin, append a hint
("7.7 GB on disk · 13 GB listed"). On-disk remains what totals/removal use.

### 5. Auto-update (Sparkle)
- Add Sparkle via SPM. `SUFeedURL = https://scrubmac.app/appcast.xml`,
  `SUPublicEDKey` in Info.plist, `SUEnableAutomaticChecks = YES`.
- Generate EdDSA keypair (`generate_keys`); private key stored safely (Keychain +
  offline backup, alongside the Apple Developer ID). Public key shipped in app.
- `release.sh`: after notarize, run `sign_update` on the DMG, append an `<item>`
  to `appcast.xml` (version, URL, EdDSA sig, release-notes link), publish appcast +
  DMG to the scrub-site `public/` (Vercel).
- UX: background daily check → silent download → "Update ready — Restart to install
  / Later". Default ON; toggle in Settings.

### 6. What's New chip + changelog
- Store `lastSeenVersion` in UserDefaults. On launch, if current build > lastSeen,
  show a chip near the sidebar toggle in the toolbar.
- Click → "What's New" sheet listing this version's changes (bundled
  `Changelog.json`/Swift array, one entry per version; reused by Sparkle's notes).
- Chip clears when opened **or** dismissed; set `lastSeenVersion = current`.

### 7. Native auth (required) — biggest piece
Because the web no longer needs auth, remove Convex Auth's web flow and build one
custom native system.

**Convex data model:** `appUsers` (email, name, provider, appleSub?/googleSub?,
createdAt), `appSessions` (token, userId, createdAt, expiresAt). Optional
`emailCodes` (emailHash, codeHash, expiresAt, attempts).

**Convex HTTP actions** (on convex.site):
- `POST /native/auth/apple` — verify identityToken against Apple JWKS (aud = app
  bundle id), upsert user, create session, return {token, user}.
- `POST /native/auth/google` — verify Google idToken against Google JWKS (aud =
  native OAuth client id), upsert, session.
- `POST /native/auth/email/request` — generate 6-digit code, store hashed + expiry,
  send via SES (existing). `POST /native/auth/email/verify` — check code, upsert, session.
- `POST /native/auth/session` — validate a stored token (called on launch).

**macOS app:**
- `AuthService` (Apple via `ASAuthorizationController`; Google via
  `ASWebAuthenticationSession` + PKCE, redirect `com.levani.Scrub://oauth`; Email
  via code entry). Session token stored in **Keychain**.
- **Auth wall:** on launch, validate stored token; if none/invalid, show a full
  gate (sign-in screen) — required before the main UI. Sign-out returns to the wall.

### 8. Website → download-only
- Remove `AuthButton`, `NewsletterSignup`, the confirm/unsubscribe pages, and the
  Convex-Auth client wiring. Keep the download + PostHog.
- Likely drop Convex from the web entirely (download counter optional).

### 9. Copy rewrite (honesty)
Drop/replace claims that now contradict reality, in both the site and the app:
- Hero pill "No tracking, no account" → reframe (e.g. "Private, on-device cleanup").
- Privacy section "no account, no analytics, no network calls — nothing leaves your
  Mac" → honest version: scanning/removal happen on-device; an account is required;
  the app checks for updates and signs you in over the network; we still never read
  or upload *what you delete*.

## External setup required (some need your clicks)
- **Google:** new OAuth client of type Desktop/iOS (the current one is Web-only) +
  custom redirect scheme. (Google Cloud Console.)
- **Apple:** confirm App ID `com.levani.Scrub` has Sign in with Apple enabled (it
  does) and add the entitlement to the app target; provisioning for Developer ID.
- **Sparkle:** I generate the EdDSA key; you store the private key safely.
- **Vercel/scrubmac.app:** host `appcast.xml` + versioned DMGs.

## Build sequence (internal; shipped as one update)
1. On-device, no external deps: size hint → Settings → launch-at-login → menu bar →
   What's New chip (verifiable immediately).
2. Sparkle plumbing + release.sh + appcast hosting.
3. Native auth: Convex tables + HTTP actions → app AuthService + wall (Apple, then
   Google, then Email).
4. Website: strip auth/email, rewrite copy.
5. 3-agent verification loop.

## Verification plan
When I believe it's production-ready, spawn 3 independent subagents to audit every
feature (code correctness, edge cases, security of the auth/token handling, build,
consistency, no leftover contradictory copy). All 3 must report clean. Any finding
→ fix everything → spawn a fresh 3 → repeat until one cycle is unanimously clean.

**Honest limit:** subagents verify code/logic/build. They cannot click an OAuth
screen, install a notarized build on a clean Mac, or confirm a real update download.
Those I test directly and report results plainly.

## Risks / notes
- Native auth is security-sensitive; token verification must be done server-side
  (never trust the client). Sessions in Keychain, not UserDefaults.
- "Required account" is a real product shift; copy must be updated everywhere to stay honest.
- Sparkle/notarization/auth are only *fully* provable with real-world tests.
