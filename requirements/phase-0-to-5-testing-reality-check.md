# Phase 0-5 Testing And Reality Check

Superseded for current code by:

```txt
requirements/phase-0-to-7-testing-reality-check.md
```

## Current Product State

This document explains exactly what can be tested with the code generated so far.

Current generated scope:

- Phase 0: repo, Flutter app, backend scaffold.
- Phase 1: foreground-service + LiveKit receive-audio spike.
- Phase 2: backend Firebase Admin, LiveKit token, FCM utility scaffolding.
- Phase 3: Firebase anonymous auth, user profile, device registration, settings.
- Phase 4: group creation, invite creation, invite join, member list.
- Phase 5: online/away flow, backend LiveKit token endpoint, availability/session writes.

Important: Phase 5 is not the final product.

Not implemented yet:

- Phase 6: friend-live notification and manual nudge notifications.
- Phase 7: push-to-talk mic publishing and one-speaker lock.
- Phase 8: final minimal UI/settings/vibrant color polish.
- Phase 9: reliability hardening and tests.
- Phase 10: release packaging.

## Biggest Reality Check

If two installed APKs both tap `Go online`, they should connect/listen, but you should not expect either phone's mic audio to be heard yet.

Reason:

- Current Phase 1/5 code is receive-focused.
- The foreground LiveKit handler intentionally calls `setMicrophoneEnabled(false)`.
- Push-to-talk, lock acquisition, and mic publish are Phase 7.

So this log is expected for now:

```txt
mic is muted
```

To test actual audio receive before Phase 7, one participant must publish audio from somewhere else, for example:

- LiveKit sample/Meet client in a browser.
- Another small LiveKit test publisher.
- A temporary developer tool/client that joins the same room and publishes microphone audio.

The current APK should be judged on whether it receives/subscribes to audio, not whether it publishes mic audio.

## Manual Setup Required

### 1. Firebase Project

Create or open a Firebase project.

Enable:

- Firebase Authentication.
- Anonymous sign-in provider.
- Realtime Database.
- Cloud Messaging is part of Firebase setup; no separate client-side "enable FCM" switch is normally needed for Android token generation after the Android app is registered and `google-services.json` is installed.

Android app registration:

```txt
Package name: app.oneone.one_one_app
```

Download:

```txt
google-services.json
```

Place it here:

```txt
app/android/app/google-services.json
```

Apply database rules:

```txt
firebase/realtime-database.rules.json
```

Reality check on rules:

- Current rules are MVP/testing-friendly.
- They allow broad authenticated reads for group/member display.
- They should be tightened before any real public release.

### 2. Firebase Backend Service Account

Backend needs Firebase Admin credentials for protected APIs and later notifications.

Get it from:

```txt
Firebase Console
-> Project settings
-> Service accounts
-> Generate new private key
```

Use either option.

Option A, recommended locally:

```env
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
FIREBASE_DATABASE_URL=https://your-project-id-default-rtdb.firebaseio.com
```

Option B, explicit `.env` values:

```env
FIREBASE_PROJECT_ID=your-project-id
FIREBASE_CLIENT_EMAIL=firebase-adminsdk-xxxxx@your-project-id.iam.gserviceaccount.com
FIREBASE_PRIVATE_KEY="-----BEGIN PRIVATE KEY-----\n...\n-----END PRIVATE KEY-----\n"
FIREBASE_DATABASE_URL=https://your-project-id-default-rtdb.firebaseio.com
```

Keep these only in `backend/.env`. Do not put them in Flutter.

### 3. LiveKit Project

Use LiveKit Cloud or self-hosted LiveKit.

Required backend env:

```env
LIVEKIT_URL=wss://your-livekit-host
LIVEKIT_API_KEY=your-api-key
LIVEKIT_API_SECRET=your-api-secret
```

Keep `LIVEKIT_API_SECRET` only in backend env.

The Flutter app should never contain the LiveKit API secret.

### 4. Backend `.env`

Create:

```txt
backend/.env
```

Minimum useful Phase 5 example:

```env
NODE_ENV=development
PORT=8080
LOG_LEVEL=info

LIVEKIT_URL=wss://your-livekit-host
LIVEKIT_API_KEY=your-livekit-api-key
LIVEKIT_API_SECRET=your-livekit-api-secret

GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
FIREBASE_DATABASE_URL=https://your-project-id-default-rtdb.firebaseio.com
```

If not using `GOOGLE_APPLICATION_CREDENTIALS`, use the explicit Firebase service-account variables from above.

### 5. Backend URL For APK Testing

The app talks to the backend through:

```txt
--dart-define=ONE_ONE_API_BASE_URL=...
```

For emulator:

```txt
http://10.0.2.2:8080
```

For real phones:

- Use a public HTTPS URL if possible.
- Or use an HTTPS tunnel like ngrok/cloudflared to your local backend.
- A plain `http://192.168.x.x:8080` LAN URL may fail on Android because cleartext HTTP can be blocked by Android network security unless explicitly allowed.

Recommended testing value:

```txt
https://your-temporary-https-backend-url
```

## FCM Answer

For Phase 5:

- FCM notification sending is not a product feature yet.
- The app only captures and stores the FCM registration token in `/userDevices/{userId}/{deviceId}`.
- You still need Firebase Android config and `firebase_messaging` setup so token capture can work.

For Phase 6:

- Backend will send friend-live and nudge notifications using Firebase Admin SDK.
- Android 13+ requires notification runtime permission for visible notifications.
- Backend send uses stored FCM registration tokens.
- We should add notification channel handling and notification tap/deep-link behavior in Phase 6.

You do not send FCM directly from Flutter.

## Install And Run Checklist

### Backend

From repo root:

```sh
cd backend
cp .env.example .env
```

Edit `backend/.env` with real Firebase and LiveKit values.

Then:

```sh
npm install
npm run build
npm start
```

Health checks:

```sh
curl http://localhost:8080/healthz
curl http://localhost:8080/readyz
```

Expected:

- `/healthz` returns `ok: true`.
- `/readyz` shows:
  - `firebaseAdminConfigured: true`
  - `firebaseDatabaseConfigured: true`
  - `liveKitConfigured: true`

### Flutter App

Before building:

```txt
app/android/app/google-services.json
```

Then:

```sh
cd app
flutter pub get
```

Run on a connected Android device:

```sh
flutter run --dart-define=ONE_ONE_API_BASE_URL=https://your-backend-url
```

Build APK:

```sh
flutter build apk --debug --dart-define=ONE_ONE_API_BASE_URL=https://your-backend-url
```

APK path:

```txt
app/build/app/outputs/flutter-apk/app-debug.apk
```

For two people, give them only the APK. Do not give the codebase, `.env`, LiveKit secret, or Firebase service-account JSON.

## Phase-Wise Manual Testing

### Phase 0: Scaffold

Goal: app/backend exist.

Checklist:

- `app/` exists.
- `backend/` exists.
- Backend has `/healthz`.
- No real secrets committed.

Pass condition:

- Backend can start.
- Flutter app can resolve dependencies.

### Phase 1: Background Audio Receive Spike

Goal: foreground service can keep LiveKit receive connection alive.

Checklist:

- Install APK on receiver phone.
- Open app.
- Use `Audio spike`.
- Enter LiveKit URL and token manually.
- Tap `Check permissions`.
- Tap `Go online`.
- Persistent foreground notification appears.
- Event log reaches `connected`.
- A separate LiveKit publisher joins same room and publishes mic audio.
- Receiver hears audio while app is foregrounded.
- Receiver hears audio when app is backgrounded.
- Receiver hears audio when screen is locked.

Expected limitation:

- Receiver APK itself does not publish mic audio.
- Two APKs both online will be silent until Phase 7.

Fail conditions to note:

- No persistent foreground notification.
- LiveKit never reaches `connected`.
- Audio works foreground but stops immediately when backgrounded.

### Phase 2: Backend Foundation

Goal: backend is configured for Firebase Admin and LiveKit.

Checklist:

- `backend/.env` has Firebase Admin config.
- `backend/.env` has LiveKit config.
- `/readyz` reports Firebase and LiveKit configured.

Pass condition:

- Backend can verify Firebase ID tokens.
- Backend can create LiveKit tokens when called by Phase 5.

### Phase 3: Identity And Device

Goal: fresh install creates user/device/settings.

Checklist:

- Install APK.
- App opens past Firebase setup screen.
- Anonymous Firebase user appears in Firebase Authentication.
- Realtime Database has:

```txt
/users/{userId}
/userDevices/{userId}/{deviceId}
/userSettings/{userId}
```

- Device row has:
  - `fcmToken` not null if FCM token was available.
  - `micPermissionGranted`.
  - `notificationPermissionGranted`.
  - `batteryOptimizationIgnored`.

Pass condition:

- Reinstall on same app data preserves same local `deviceId`.
- Clearing app data creates a new anonymous identity/device.

### Phase 4: Groups And Invites

Goal: users can create/join a private group.

Device A:

- Open app.
- Save display name.
- Tap `Groups`.
- Create group.
- Create invite.
- Copy invite code.

Device B:

- Open app.
- Save display name.
- Tap `Groups`.
- Enter invite code.
- Join group.

Database checklist:

```txt
/groups/{groupId}
/groupMembers/{groupId}/{userA}
/groupMembers/{groupId}/{userB}
/groupInvites/{inviteId}
/livekitRooms/{groupId}
/memberAvailability/{groupId}/{userA}
/memberAvailability/{groupId}/{userB}
```

Pass condition:

- Raw invite code is not stored in `/groupInvites`.
- Only `inviteCodeHash` is stored.
- Fifth active member should be rejected.

### Phase 5: Online/Away LiveKit

Goal: user can go online, receive LiveKit token, start service, write live availability.

Device A:

- Open `Groups`.
- Select group.
- Tap `Online mode`.
- Tap `Go online`.

Expected database writes:

```txt
/appServiceSessions/{serviceSessionId}
/livekitSessions/{livekitSessionId}
/livekitTokenIssuances/{tokenId}
/memberAvailability/{groupId}/{userId}
```

Expected availability while connected:

```json
{
  "desiredState": "online",
  "effectiveState": "live",
  "serviceState": "running",
  "livekitConnectionState": "connected",
  "canReceiveLiveAudio": true
}
```

Expected away state after tapping `Go away`:

```json
{
  "desiredState": "away",
  "effectiveState": "away",
  "serviceState": "stopped",
  "livekitConnectionState": "disconnected",
  "canReceiveLiveAudio": false
}
```

Reality check:

- The LiveKit foreground service should connect and subscribe.
- Mic publishing is still not expected.
- Friend-live notification is still not expected.
- Nudge notification is still not expected.

## Product Readiness At Phase 5

Phase 5 is enough to prove:

- Auth identity works.
- Device registration works.
- Group membership works.
- Backend auth-protected APIs work.
- Backend can issue LiveKit tokens.
- App can start online mode.
- Firebase availability model is being populated.

Phase 5 is not enough for:

- Ten Ten-style talking from the app.
- Nudge notifications.
- Friend-live notifications.
- One-speaker-at-a-time locking.
- Final UI/settings polish.
- Production release.

## Known Technical Risks

### Foreground Service Heartbeat

Current Phase 5 heartbeat is controller/UI based.

The LiveKit connection is attempted inside the foreground-service task, but Firebase heartbeat writes are not fully service-owned yet.

If Android testing shows heartbeat stops when UI is closed, Phase 9 must move Firebase heartbeat writes into the foreground service or a minimal native Android service bridge.

### HTTP Backend URL

Real phones should use HTTPS backend URL.

If using plain HTTP on LAN, Android may block it unless cleartext traffic is explicitly allowed.

### Notifications

FCM token capture can work now.

Actual friend-live and nudge notifications require Phase 6.

### Audio Publish

Mic publish is not implemented yet.

Phase 7 must:

- Acquire Firebase talk lock.
- Enable/publish microphone only after lock acquired.
- Disable/unpublish microphone on release.
- Release or expire lock safely.

## Source References

- Firebase Cloud Messaging Android setup and Android 13 notification permission: https://firebase.google.com/docs/cloud-messaging/android/get-started
- Firebase Cloud Messaging Flutter setup: https://firebase.google.com/docs/cloud-messaging/flutter/get-started
- Firebase Admin SDK send docs: https://firebase.google.com/docs/cloud-messaging/send/admin-sdk
- Android notification runtime permission: https://developer.android.com/develop/ui/compose/notifications/notification-permission
