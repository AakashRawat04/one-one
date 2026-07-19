# One One App

Android-first Flutter client for the One One LiveKit walkie-talkie app.

The app starts through Google-backed Firebase Authentication and device registration.

Before running after Phase 3, add:

```txt
android/app/google-services.json
```

For Google authentication, enable the Google provider in Firebase Auth, add
the Android debug/release SHA fingerprints, and re-download
`google-services.json`. The file must include a web OAuth client
(`oauth_client` with `client_type: 3`) for the Google Sign-In plugin.

Then run:

```sh
flutter pub get
flutter run
```

RevenueCat builds also require the public platform SDK key via
`ONE_ONE_REVENUECAT_ANDROID_API_KEY` / `ONE_ONE_REVENUECAT_APPLE_API_KEY` dart
defines. See `requirements/revenuecat-subscription-setup.md` for the product,
offering, Remote Config, grace-period, and developer-code rollout checklist.

Phase 1 still contains a LiveKit background-audio spike under `lib/phase1_spike/`.

The spike:

- Starts an Android foreground service from the visible UI.
- Keeps a persistent `walkie_service` notification while online.
- Connects to LiveKit from the foreground-service task isolate using a temporary URL/token entered in the app.
- Auto-subscribes to remote audio and keeps the local mic muted.
- Sends heartbeat/status events back to the UI.

Runtime verification must be done manually on Android devices with a valid Firebase config and LiveKit URL/token.

## Android Nudges

The home-screen notification button opens Push, Ring, and Voice nudge actions.
Voice recordings are AAC/M4A, mono, 64 kbps, and capped at six seconds. Incoming
Ring and Voice nudges are handled by native Android services and can play while
the screen is locked or the Flutter process is absent, provided the app has not
been force-stopped and the device is online.

Deploy the backend and Firebase rules described in
`requirements/android-nudge-delivery.md` before device testing.
For registration and delivery diagnosis, follow
`requirements/fcm-end-to-end-checklist.md` in order.

FCM registration uses the Firebase Installation ID flow in Firebase Messaging
25+. In Firebase, enable the Cloud Messaging API and ensure the Android Firebase
API key allows both the Firebase Installations API and FCM Registration API.
Do not put a service-account key or legacy FCM server key in the app.

## Run

```sh
flutter pub get
flutter run
```

## Android Scope

This project was generated with `--platforms=android`. iOS, web, macOS, Linux, and Windows are intentionally out of scope for the MVP.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
