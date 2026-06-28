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
The shipped Developer ID build uses Apple's web OAuth flow, not the native
`ASAuthorizationAppleIDProvider` token flow. Native Sign in with Apple requires a
Developer ID provisioning profile with the Apple Sign In capability; until that
exists, the direct-download DMG must use the Services ID route.

Required production settings:
1. Apple Developer → Services ID `app.scrubmac.web`.
2. Return URL registered in Apple Developer:
   `https://scrubmac.app/api/auth/callback/apple`.
3. Convex prod env:
   `AUTH_APPLE_ID=app.scrubmac.web` and a valid `AUTH_APPLE_SECRET` client-secret
   JWT for the same Services ID.

Runtime flow:
1. Scrub opens `https://appleid.apple.com/auth/authorize`.
2. Apple redirects to `https://scrubmac.app/api/auth/callback/apple`.
3. The site redirects back to Scrub with `com.levani.scrub.auth:/apple/callback`.
4. Scrub sends the authorization code to `/native/auth/apple-code`.
5. Convex exchanges the code server-side and verifies the returned Apple ID token.

## 3. Email codes
Already wired (`/native/auth/email/request` + `/verify`, SES, hashed codes,
10-min expiry, 5-attempt cap). Real delivery to arbitrary inboxes needs SES out
of sandbox (production-access request already submitted).

## 4. Tests that need you
- Real **Apple** sign-in (your Apple ID + 2FA) → confirms the token round-trip.
- Real **Google** sign-in once the client exists.
- **Email** code to an inbox once SES production access lands.
