# Android group invite links

## Implemented flow

1. `POST /v1/groups/:groupId/invites` returns the existing one-time PIN plus an
   HTTPS `inviteUrl`.
2. Android shares the HTTPS URL through the system share sheet.
3. A verified link opens `MainActivity`. The invite code is persisted natively,
   so the link survives a cold start, Google authentication, and onboarding.
4. Once an authenticated identity is ready, the app calls the existing join
   endpoint, clears the pending code only after success (or a terminal invite
   error), and opens Home focused on the joined group.
5. The PIN remains available as a fallback.

## One-time deployment setup

- Set `PUBLIC_INVITE_BASE_URL=https://one-one-xw00.onrender.com/invite` on the
  backend. If the public host changes, update the HTTPS host in
  `AndroidManifest.xml` and `InviteLinkContract.httpsHost` in the same release.
- In Play Console, copy the SHA-256 certificate fingerprint from **Setup > App
  integrity > App signing key certificate**.
- Set `ANDROID_APP_LINK_SHA256_CERT_FINGERPRINTS` on the backend. Use a
  comma-separated list when both Play signing and an internal/test signing
  certificate must open verified links.
- Deploy the backend and confirm
  `https://one-one-xw00.onrender.com/.well-known/assetlinks.json` returns the
  package `app.oneone.one_one_app` and every expected SHA-256 fingerprint as
  JSON, without authentication or a redirect.
- Deploy the backend before distributing an app build that shares these links.
  Without domain verification, the HTTPS endpoint still redirects installed
  Android devices to `oneone://invite/<code>` as a compatibility fallback.

## Device verification

- Create an invite and share it to the second Android device.
- Test while logged in, logged out, and after removing the app from Recents.
- In each state, tap the link and confirm the recipient joins without entering
  the PIN and lands with the invited group selected.
- Test an expired and fully-used invite; the app must show the server error and
  must not repeatedly retry that terminal link.
