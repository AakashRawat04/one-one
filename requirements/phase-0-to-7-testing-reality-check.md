# Phase 0-7 Testing And Reality Check

## Current State

Generated through Phase 7:

- Phase 0: scaffold.
- Phase 1: foreground-service LiveKit receive spike.
- Phase 2: backend Firebase Admin and LiveKit utilities.
- Phase 3: Firebase anonymous auth, user/device/settings.
- Phase 4: groups, invites, membership.
- Phase 5: online/away, LiveKit token, availability.
- Phase 6: push notification work is currently disabled in the Flutter app.
- Phase 7: push-to-talk, talk lock, mic publish command.

Still not done:

- Phase 8: final minimal UI/settings/vibrant themes.
- Phase 9: hardening, diagnostics, tests.
- Phase 10: release packaging.

## Required Manual Setup

Firebase:

- Register Android app with package `app.oneone.one_one_app`.
- Download `google-services.json` to `app/android/app/google-services.json`.
- Enable Firebase Authentication anonymous sign-in.
- Create Realtime Database.
- Apply `firebase/realtime-database.rules.json`.
- Backend needs Firebase Admin service account via `GOOGLE_APPLICATION_CREDENTIALS` or explicit service-account env values.

LiveKit:

- Set backend env:

```env
LIVEKIT_URL=wss://your-livekit-host
LIVEKIT_API_KEY=your-api-key
LIVEKIT_API_SECRET=your-api-secret
```

Backend:

```env
NODE_ENV=development
PORT=8080
LOG_LEVEL=info
GOOGLE_APPLICATION_CREDENTIALS=/absolute/path/to/service-account.json
FIREBASE_DATABASE_URL=https://your-project-id-default-rtdb.firebaseio.com
```

App:

```sh
flutter run \
  --dart-define=ONE_ONE_API_BASE_URL=https://your-backend-url \
  --dart-define=ONE_ONE_FIREBASE_DATABASE_URL=https://your-project-id-default-rtdb.region.firebasedatabase.app
```

Use HTTPS for real phones if possible.

The Flutter app and backend must use the exact same Realtime Database URL.
For the current Firebase project, use:

```txt
https://oneone-3adb5-default-rtdb.asia-southeast1.firebasedatabase.app
```

If the app writes `/users/{uid}` to one database but the backend reads another
database, backend group creation fails with `user_not_found`.

## Push Notification Reality Check

FCM has been removed from the current Flutter client to simplify real-device testing.

Current consequences:

- No Firebase Messaging dependency in the Flutter app.
- No FCM token is captured under `/userDevices/{userId}/{deviceId}`.
- Friend-live push notifications are not sent by the app.
- Nudge buttons are hidden from the app.
- Android notification permission may still be requested by the foreground service because Android requires a visible foreground-service notification.

LiveKit audio is not dependent on FCM. Users who have gone online should still be able to receive LiveKit audio through the foreground service.

## End-To-End Checklist

### Identity

- Install APK.
- Confirm anonymous user appears in Firebase Auth.
- Confirm records:

```txt
/users/{userId}
/userDevices/{userId}/{deviceId}
/userSettings/{userId}
```

### Groups

- Device A creates group.
- Device A creates invite.
- Device B joins invite.
- Confirm:

```txt
/groups/{groupId}
/groupMembers/{groupId}/{userA}
/groupMembers/{groupId}/{userB}
/livekitRooms/{groupId}
/memberAvailability/{groupId}/{userA}
/memberAvailability/{groupId}/{userB}
```

### Online

- Both devices open `Online mode`.
- Both tap `Go online`.
- Confirm foreground notification appears.
- Confirm each user reaches:

```json
{
  "desiredState": "online",
  "effectiveState": "live",
  "canReceiveLiveAudio": true
}
```

### Push-To-Talk

- Both devices are online in the same group.
- Device A holds `HOLD TO TALK`.
- Confirm:

```txt
/talkLocks/{groupId}
/talkSessions/{groupId}/{talkSessionId}
```

- Device B should hear Device A.
- While Device A is holding, Device B holding talk should fail/busy.
- Device A releases.
- Confirm lock is removed.
- Device B can now hold and talk.

## Mic Reality Check

Before Phase 7, the mic was intentionally muted. After Phase 7:

- Mic should enable only while holding the talk button.
- Mic should mute immediately on release/cancel.
- If audio still does not publish, check foreground task events for `mic_failed`.
- Android must grant microphone permission.
- Foreground service now requests both `mediaPlayback` and `microphone` service types.

## Known Risks

- Firebase rules are permissive for testing and must be hardened before release.
- Heartbeat is still partly UI-controller based; Phase 9 should move more reliability work into the service/native layer if Android background testing exposes stale heartbeat issues.
- Push notifications/nudges are disabled in the Flutter app. Reintroduce FCM later if out-of-app alerts are required.
- Release signing/App Distribution is still Phase 10.
