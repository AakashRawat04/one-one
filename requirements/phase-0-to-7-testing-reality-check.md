# Phase 0-7 Testing And Reality Check

## Current State

Generated through Phase 7:

- Phase 0: scaffold.
- Phase 1: foreground-service LiveKit receive spike.
- Phase 2: backend Firebase Admin, LiveKit, FCM utilities.
- Phase 3: Firebase anonymous auth, user/device/settings.
- Phase 4: groups, invites, membership.
- Phase 5: online/away, LiveKit token, availability.
- Phase 6: friend-live and nudge notification APIs/UI hooks.
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
flutter run --dart-define=ONE_ONE_API_BASE_URL=https://your-backend-url
```

Use HTTPS for real phones if possible.

## FCM Reality Check

For Android, after Firebase app setup and `google-services.json`, FCM token capture should work through `firebase_messaging`.

You still need:

- Android notification permission granted on Android 13+.
- Backend Firebase Admin credentials.
- Stored `fcmToken` under `/userDevices/{userId}/{deviceId}`.

No client-side Firebase secret is needed. The Flutter app must not send FCM directly.

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

### Friend-Live Notification

- When Device A becomes live, backend should create:

```txt
/notificationEvents/{groupId}/{notificationEventId}
/notificationDeliveries/{notificationEventId}/{deliveryId}
```

- Device B should receive notification if FCM token and notification permission are valid.

### Nudge

- Device A opens group screen.
- Tap member nudge or `Nudge all`.
- Confirm backend creates nudge notification event and delivery records.
- Device B should receive nudge notification.

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
- Notification tap deep-link handling is not polished.
- Release signing/App Distribution is still Phase 10.
