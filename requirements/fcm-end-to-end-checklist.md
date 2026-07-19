# Firebase / FCM Android End-to-End Checklist

Use this checklist in order. Do not skip directly to sending a nudge: Android
registration, Realtime Database persistence, backend targeting, delivery, and
native playback are separate checkpoints.

## 1. Confirm the APK contains the current native code

- Native Kotlin and manifest changes require a full Android rebuild. Hot reload
  and hot restart are insufficient.
- Open the rebuilt app and locate `[FCM-01]` in Logcat. If it is absent, the
  installed APK is stale.
- `[FCM-01]` must report:
  - `package=app.oneone.one_one_app`
  - `projectId=oneone-3adb5`
  - a non-empty `firebaseAppId` and `senderId`
  - `installationIdEnabled=true`
  - a Google Play Services version rather than `missing`
- Compare the logged `signingSha1` exactly with Firebase Console. This avoids
  relying on a SHA printed for a different debug, upload, or Play signing key.

To show only relevant device logs on this Mac:

```sh
$HOME/Library/Android/sdk/platform-tools/adb logcat -c
$HOME/Library/Android/sdk/platform-tools/adb logcat -v time OneOneFCM:I flutter:I FirebaseMessaging:I '*:S'
```

## 2. Firebase Console: Android app and Authentication

In **Project settings > General > Your apps**, verify:

- Firebase project: `oneone-3adb5`
- Android package: `app.oneone.one_one_app`
- The SHA-1 printed by `[FCM-01]` is registered.
- Add all variants that are actually used: local debug, release/upload, and
  Google Play App Signing SHA-1 certificates.
- Download a fresh `google-services.json` after changing Android app or OAuth
  configuration and replace `app/android/app/google-services.json`.

In **Authentication > Sign-in method**, enable Google. The downloaded Android
configuration must contain a web OAuth client (`oauth_client` with
`client_type: 3`) for the Flutter Google Sign-In flow. OAuth configuration is
not required for FCM registration, but a missing client breaks login before the
normal identity/device sync can run.

## 3. Google Cloud Console: Android API key

For **Android key (auto created by Firebase)**:

- API restrictions must include **Firebase Installations API** and
  **FCM Registration API**. **Firebase Cloud Messaging API** should also be
  enabled for the project.
- `Application restrictions: None` permits registration but is less secure.
- If **Android apps** is selected, add package `app.oneone.one_one_app` with
  every SHA-1 used to sign an installed build. A missing SHA causes calls from
  that build to be rejected.
- Wait at least five minutes after changing restrictions before retesting.
- Never put a service-account private key in the Android application.

In **Firebase Project settings > Cloud Messaging**, confirm the Cloud Messaging
API is enabled.

## 4. Device prerequisites

- Google Play Store and current Google Play Services must be installed and
  enabled.
- Set Android date and time to automatic.
- Test once without VPN, private DNS, firewall, or an ad-blocking DNS profile.
- Ensure the app has network access and has not been force-stopped.
- Notification permission affects visible notifications, but it does not
  normally prevent creation of the registration identifier.

## 5. Android registration checkpoints

The successful sequence is:

```txt
[FCM-01] runtime configuration
[FCM-02] Flutter requested FCM installation registration
[FCM-03] FCM backend registration completed
[FCM-04] Firebase Installation ID resolved length=22 ...
[FCM-05] Registered identifier saved locally
[FCM-06] onRegistered callback
[DART-02] Registration identifier received
[DART-03] Identity startup registrationAvailable=true
```

With automatic initialization, `[FCM-06]` can occur before Flutter requests
`[FCM-02]`; this is valid. The important result is that registration reaches
`[FCM-04]` and Dart receives the identifier.

Failure routing:

| Log/error | Inspect |
| --- | --- |
| `[FCM-E0]` | Missing/mismatched `google-services.json` or Firebase initialization |
| `API_KEY_SERVICE_BLOCKED`, HTTP 403 | API allowlist or Android package/SHA restriction |
| `FIS_AUTH_ERROR`, `INVALID_SENDER` | Wrong/stale Firebase config or project/sender mismatch |
| `AUTHENTICATION_FAILED`, `PHONE_REGISTRATION_ERROR` | Google Play Services, Google account, device time, or device firmware |
| `SERVICE_NOT_AVAILABLE`, `TIMEOUT` | Device network, VPN/private DNS/firewall, or temporary Google service failure |
| `[FCM-E1]` | Read the exception and nested `cause[n]` lines emitted immediately after it |
| `[FCM-E2]` | Firebase Installations ID lookup failed after FCM registration |
| `[DART-E2]` | Native failure reached Flutter; match its code with `[FCM-E1/E2]` |

Do not diagnose from the generic `FirebaseMessaging` line alone. Capture the
`OneOneFCM` lines, which include the nested exception chain.

## 6. Realtime Database device record

After Google authentication, the successful sequence continues with:

```txt
[DART-04] userDevices record written registrationAvailable=true
[DART-05] Device registration synchronized to Firebase
```

In Realtime Database, verify:

```txt
/userDevices/{firebaseAuthUid}/{deviceId}/platform = "android"
/userDevices/{firebaseAuthUid}/{deviceId}/deviceState = "active"
/userDevices/{firebaseAuthUid}/{deviceId}/fcmToken = <non-empty>
```

For new app installs, the compatibility-named `fcmToken` field contains a
22-character registered Firebase Installation ID. `[DART-E4]` means this
database write failed; inspect authentication and Realtime Database rules.

## 7. Backend deployment and Firebase Admin

- The deployed backend must contain the current FID-compatible messaging code;
  changing local source does not update Render or another host automatically.
- `FIREBASE_PROJECT_ID` must be `oneone-3adb5`.
- `FIREBASE_DATABASE_URL`, `FIREBASE_STORAGE_BUCKET`, and
  `PUBLIC_API_BASE_URL` must match the deployed project and HTTPS backend.
- Use exactly one credential source:
  - attached identity/Application Default Credentials, or
  - backend-only `FIREBASE_CLIENT_EMAIL` and `FIREBASE_PRIVATE_KEY` secrets.
- Keep the active service-account key until the deployed backend has been
  migrated to another credential source. Never expose it to the client.
- The backend identity needs permissions for FCM sends, Realtime Database,
  Firebase Authentication custom claims, and Storage object operations.

Expected backend logs:

```txt
FCM-BE-00  Firebase Admin initialized for the expected project
FCM-BE-01  Batch started; targetCount > 0 and fidCount > 0
FCM-BE-02  successCount > 0
```

`FCM-BE-W0` means no registered recipient devices were found. `FCM-BE-W1`
includes per-target FCM failure codes. `FCM-BE-E1` means the whole
Admin SDK call failed, commonly due to credentials, IAM, API enablement, or a
project mismatch. If `targetCount=0`, registration/persistence or group-recipient
selection failed before FCM was called.

## 8. Delivery and native playback

Expected Android behavior by state:

| Nudge | Foreground | Background | Removed from Recents / locked |
| --- | --- | --- | --- |
| Push | Native service displays actionable `[FCM-08]` notification | High-priority data message builds actionable native notification | High-priority data message builds actionable native notification |
| 3/5/10-second Ring | Native service rings | High-priority data message starts playback service | High-priority data message starts playback service |
| Voice | Native service downloads and plays | High-priority data message starts playback service | High-priority data message starts playback service |

“Removed from Recents” is supported. Android force-stop is not: after a user
force-stops the app in system settings, Android blocks FCM delivery until the
app is opened manually.

On the receiver, expect:

```txt
[FCM-07] Message received
[FCM-09] Starting native playback
[FCM-10..11] Native service accepted and queued the nudge
[FCM-11A] Bounded playback wake lock acquired
[FCM-12..15] Ring/voice playback completed
[FCM-16] Delivery acknowledgement reached the backend
[FCM-17] Nudge finished successfully
```

- `[FCM-08]` confirms that a foreground Push/Friend Live notification was displayed.
- `[FCM-W1..W5]` explains why a native nudge payload was rejected.
- `[FCM-E3]` means Android refused to start the playback foreground service.
- `[FCM-E8/E9]` means Android failed to acquire or release the bounded playback wake lock.
- `[FCM-W6]` means the playback service received an invalid start request.
- `[FCM-W7]` means FCM discarded queued messages before delivery.
- `[FCM-W8..W10]` means an actionable nudge was missing its event/group routing data.
- `[NUDGE-ACTION-01..03]` traces notification response upload, app action queuing, and sender response receipt.
- Force-stopping the app prevents delivery until the user manually opens it.
- A powered-off phone cannot receive or play a nudge; it can only receive after
  boot and reconnection if the message has not expired.

## 9. Minimal evidence to collect after a failed run

Provide these together:

1. All `OneOneFCM` and `FirebaseMessaging` lines from a fresh app launch.
2. The `[FCM-01]` line with app ID, project, sender ID, SHA-1, and GMS version.
3. Whether the RTDB `userDevices` record has a non-empty `fcmToken`.
4. Backend `FCM-BE-00/01/02/W1/E1` lines for the same send attempt.
5. Whether `[FCM-07]` appeared on the receiver.

These five items identify the failing boundary without exposing any secret or
full device identifier.

## 10. Nudge throttling

The backend protects users from spam, but the previous hardcoded limit of five
nudges per ten minutes blocked a test immediately after Push, 3-second Ring,
5-second Ring, 10-second Ring, and Voice were tried once. The defaults are now:

```txt
NUDGE_RATE_LIMIT_WINDOW_SECONDS=600
NUDGE_RATE_LIMIT_MAX_PER_GROUP=30
NUDGE_RECIPIENT_COOLDOWN_SECONDS=5
```

These can be set in the backend environment without an Android release.
`NUDGE-BE-W1` and `NUDGE-BE-W2` explicitly identify throttling before FCM is
called. The app now shows the backend retry message instead of reporting a
generic connection failure.
