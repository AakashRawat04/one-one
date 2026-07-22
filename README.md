# One One

Android-first Flutter + LiveKit walkie-talkie app for a small private friend group.

The implementation follows:

- `requirements/flutter-livekit-erd.md`
- `requirements/flutter-livekit-tech-plan.md`
- `requirements/flutter-livekit-agent-phase-prompts.md`

## Repo Structure

```txt
app/          Flutter Android client
backend/      Node/TypeScript token API
requirements/ Planning docs and implementation handoffs
```

## Flutter App

After Phase 3, add Firebase Android config first:

```txt
app/android/app/google-services.json
```

```sh
cd app
flutter pub get
flutter run \
  --dart-define=ONE_ONE_API_BASE_URL=https://your-backend-url \
  --dart-define=ONE_ONE_FIREBASE_DATABASE_URL=https://oneone-3adb5-default-rtdb.asia-southeast1.firebasedatabase.app
```

Current state: Phase 1 audio spike, Phase 3 Firebase anonymous identity/device registration, Phase 4 groups/invites, Phase 5 online/away token/availability flow, Phase 7 push-to-talk, subscriptions, and Android nudge delivery.

Android FCM registration is active. Push, 3/5/10-second ring, and six-second
voice nudges are available from the home-screen nudge button. Timed rings use
One One's own two-chime sound and an exact-length PCM buffer instead of the
phone ringtone. Ring and voice nudges use a native foreground playback service
so Flutter does not need to be running. See
`requirements/android-nudge-delivery.md` before deployment.

Group invites now include a shareable HTTPS link. On Android, opening that link
preserves the invite through authentication/onboarding, joins the group, and
focuses it on Home. See `requirements/android-invite-links.md` for the one-time
domain verification setup.

## Backend

```sh
cd backend
cp .env.example .env
npm install
npm run dev
```

Health check:

```sh
curl http://localhost:8080/healthz
```

Readiness:

```sh
curl http://localhost:8080/readyz
```

## Implementation Order

Follow the phases in `requirements/flutter-livekit-agent-phase-prompts.md`. Phase 7 is not the final product phase; final UI/settings, reliability, and release packaging remain.

Before APK testing, read:

```txt
requirements/phase-0-to-7-testing-reality-check.md
```
