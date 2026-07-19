# Android Nudge Delivery

## Runtime flow

1. Flutter records a maximum six-second AAC/M4A voice nudge and uploads it to
   the authenticated backend.
2. The backend stores it privately in Firebase Storage, creates one opaque
   delivery token per active Android device, and sends a high-priority,
   data-only FCM message.
3. `VoiceNudgeMessagingService` starts `VoiceNudgePlaybackService`. The
   foreground service holds a bounded CPU wake lock, downloads and plays the
   recording without starting Flutter, then acknowledges completion.
4. The backend deletes the Storage object after every intended recipient has
   played it. Media expires after ten minutes when accessed; a bucket lifecycle
   rule is the final cleanup safety net.

The same native service produces the three-, five-, and ten-second Ring nudge.
Ordinary Push nudges now use the same high-priority data path so Android can
render Accept, Snooze (5 or 15 minutes), and Decline actions consistently in
every app state.

Push notifications are displayed explicitly by the native messaging service in
every state. Ring and Voice use high-priority data messages so the native
playback service can run without Flutter. Their foreground-service notification
is detached and replaced with an actionable, auto-cancel notification after
playback, so it remains in Notification Center.

Timed rings use an app-owned, repeating two-chime PCM pattern rather than the
device's call ringtone. A complete 44.1 kHz mono buffer is generated for the
selected 3/5/10-second duration, so the audible cue itself ends at the requested
boundary; service cleanup uses that same deadline. The `voice_nudges` notification channel stays
silent because the foreground service owns voice/ring playback; using a channel
sound would create a second, duration-uncontrolled sound.

## Required backend configuration

In Firebase Console, open **Project settings > Cloud Messaging** and enable the
Cloud Messaging API. In Google Cloud Console, verify that the API key referenced
by `app/android/app/google-services.json` is allowed to call:

```txt
firebaseinstallations.googleapis.com
fcmregistrations.googleapis.com
```

These are the Firebase Installations API and FCM Registration API. The Android
app contains only the Firebase client configuration. Never copy a service-account
private key or legacy FCM server key into the app.

Set these values in the deployed backend:

```txt
FIREBASE_PROJECT_ID=oneone-3adb5
FIREBASE_DATABASE_URL=https://oneone-3adb5-default-rtdb.asia-southeast1.firebasedatabase.app
FIREBASE_STORAGE_BUCKET=oneone-3adb5.firebasestorage.app
PUBLIC_API_BASE_URL=https://your-public-api.example.com
```

The Firebase Admin identity needs Realtime Database, Firebase Cloud Messaging,
and Storage object read/write/delete permissions. `PUBLIC_API_BASE_URL` must be
HTTPS because Android rejects cleartext traffic by default.

Deploy the Firebase rules:

```sh
firebase deploy --only database,storage
```

Configure a Cloud Storage lifecycle rule to delete objects under
`voiceNudges/` after one day. Normal ACK cleanup is immediate; the lifecycle
rule covers devices that never reconnect and backend interruptions.

## Device prerequisites

- Current Google Play services and a valid `android/app/google-services.json`
  whose Android package is `app.oneone.one_one_app`.
- Microphone permission for the sender.
- Notification permission for reliable user-visible high-priority delivery.
- The recipient app must have been opened at least once and must not be
  force-stopped in Android Settings.
- The phone must be powered on and online.

## Manual acceptance test

Use two physical Android devices signed into different group members:

1. Open both apps once and confirm each `userDevices` record contains an
   `fcmToken` and `platform: android`. For new installs, the compatibility-named
   `fcmToken` field contains the registered Firebase Installation ID.
2. Lock the receiver and send 3-, 5-, and 10-second Ring nudges. Confirm the
   sound is One One's two-chime pattern (not the call ringtone), measure each
   from audible start to stop, and confirm it matches the selected duration.
3. Swipe the receiver from Recents, send a Voice nudge, and confirm it downloads
   and plays without opening Flutter.
4. Confirm the delivery progresses through `sent`, `downloaded`, and `played`,
   and that the Storage object is removed after recipient ACKs.
5. Force-stop the receiver and confirm no claim of delivery is made; Android
   intentionally blocks all app components until the user opens the app again.
