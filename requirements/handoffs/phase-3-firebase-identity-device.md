# Phase 3 Handoff: Firebase Identity, Profile, Device

## Status

Code generated. Manual Flutter dependency resolution and Android verification are pending.

## Implemented

- Firebase initialization gate in Flutter.
- Anonymous Firebase Auth sign-in.
- User profile upsert at `/users/{userId}`.
- Device registration at `/userDevices/{userId}/{deviceId}`.
- Default settings creation at `/userSettings/{userId}`.
- Persistent local install/device ID through SharedPreferences.
- FCM token capture and refresh listener.
- Permission diagnostics for microphone, notifications, and battery optimization.
- Minimal profile screen with display-name save.
- Route to the existing Phase 1 audio spike screen.
- Phase 3 Realtime Database rules file.

## Files Added Or Changed

- `app/pubspec.yaml`
- `app/android/settings.gradle.kts`
- `app/android/app/build.gradle.kts`
- `app/lib/main.dart`
- `app/lib/app/one_one_app.dart`
- `app/lib/app/firebase_setup_blocked_screen.dart`
- `app/lib/features/identity/data/device_identity_store.dart`
- `app/lib/features/identity/data/identity_repository.dart`
- `app/lib/features/identity/models/app_user_profile.dart`
- `app/lib/features/identity/models/identity_session.dart`
- `app/lib/features/identity/models/user_device_record.dart`
- `app/lib/features/identity/models/user_settings_record.dart`
- `app/lib/features/identity/ui/identity_home_screen.dart`
- `firebase/README.md`
- `firebase/realtime-database.rules.json`

## Required Manual Setup Before Running

1. Add Android app in Firebase using package:

```txt
app.oneone.one_one_app
```

2. Download config file to:

```txt
app/android/app/google-services.json
```

3. Enable Firebase Authentication anonymous sign-in.
4. Create Firebase Realtime Database.
5. Apply rules from:

```txt
firebase/realtime-database.rules.json
```

6. From `app/`, run:

```sh
flutter pub get
```

## Expected First-Run Writes

```txt
/users/{userId}
/userDevices/{userId}/{deviceId}
/userSettings/{userId}
```

## Notes

- No backend secrets are in Flutter.
- `google-services.json` is not a backend secret, but it is required for Android Firebase initialization.
- Group invite, membership, online availability, backend token issuance, nudges, and push-to-talk are intentionally not implemented in Phase 3.
- Existing Phase 1 audio spike is still available from the new home screen through the `Audio spike` button.
