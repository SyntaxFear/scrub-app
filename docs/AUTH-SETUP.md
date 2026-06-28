# Native auth — finishing setup

The app, the sign-in wall, and the Convex backend (verified live) are all built.
What remains needs your Apple/Google logins, which I can't do. Each item below is
small and clearly scoped.

## Backend (already live & smoke-tested)
Convex prod `healthy-shepherd-34` exposes, at
`https://healthy-shepherd-34.eu-west-1.convex.site/native/auth/…`:
`apple`, `google`, `email/request`, `email/verify`, `session`, `signout`.
All verify tokens/codes server-side. Tested: bad token → 401, missing field →
400, Google-unconfigured → 503, garbage JWT → 401 (jose rejects).

## 1. Google sign-in
1. Google Cloud Console → the **Scrub** project (`scrub-500707`) → Credentials →
   Create OAuth client ID → type **Desktop app** (or iOS). Note the **client ID**
   and **client secret**, and the **custom URI scheme** it gives you.
2. In `Scrub/Services/AuthService.swift`, fill `GoogleConfig`:
   `clientID`, `clientSecret`, and `scheme` (the reverse-DNS scheme from step 1;
   `redirectURI` is `scheme:/oauth2redirect`).
3. Set the verification audience on the backend (dev + prod):
   ```
   npx convex env set GOOGLE_NATIVE_CLIENT_ID "<the client ID>"
   npx convex env set --prod GOOGLE_NATIVE_CLIENT_ID "<the client ID>"
   ```
   (Until set, `/native/auth/google` returns 503 and the Google button is hidden.)

## 2. Sign in with Apple
1. developer.apple.com → Identifiers → App ID `com.levani.Scrub` → ensure
   **Sign in with Apple** is enabled (the web Services ID already uses it).
2. Add the entitlement to `Scrub/Scrub.entitlements`:
   ```xml
   <key>com.apple.developer.applesignin</key>
   <array><string>Default</string></array>
   ```
   (Left out for now so the ad-hoc Debug build keeps working without provisioning.)
3. For Developer ID distribution, create/download a provisioning profile that
   includes the Sign in with Apple capability and embed it in the app
   (`PROVISIONING_PROFILE_SPECIFIER`). The backend already expects `aud` =
   `com.levani.Scrub`.

## 3. Email codes
Already wired (`/native/auth/email/request` + `/verify`, SES, hashed codes,
10-min expiry, 5-attempt cap). Real delivery to arbitrary inboxes needs SES out
of sandbox (production-access request already submitted).

## 4. Tests that need you
- Real **Apple** sign-in (your Apple ID + 2FA) → confirms the token round-trip.
- Real **Google** sign-in once the client exists.
- **Email** code to an inbox once SES production access lands.
