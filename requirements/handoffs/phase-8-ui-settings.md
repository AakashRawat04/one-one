# Phase 8 Handoff: Minimal UI, Settings, And Themes

## Status

Code generated and statically analyzed. APK build/runtime verification is pending with the user.

## Implemented

- Replaced the first screen with a minimal voice-first home screen.
- Home screen shows:
  - current user display name and live/away/talking state
  - current group selector or create/join group setup
  - large hold-to-talk mic control
  - go online / go away controls
  - setup warning entry point
  - friend availability list
- Added Settings screen with:
  - display name editing
  - accent selector
  - haptics toggle
  - speaker/phone audio output preference
  - background reliability checklist
- Added vibrant accent keys:
  - `coral`
  - `lime`
  - `sky`
  - `violet`
  - `amber`
  - `pink`
  - `teal`
- Settings persist to `/userSettings/{userId}`.
- App theme updates from `accentColorKey`.

## Explicit Scope Choice

Nudge actions were intentionally not implemented in this phase because the latest instruction was to ignore nudge-related parts.

## Important Runtime Reality

The current APK path is simplified for working foreground voice:

- User taps Go online.
- The UI connects directly to LiveKit.
- Hold-to-talk enables the local LiveKit microphone.
- Friends in the same group hear the audio while their app is online and connected.

Closed-app receive is still not complete in this simplified path. The setup and settings screens show that caveat so testers do not confuse foreground MVP behavior with full background reliability.

## Files Added Or Changed

- `app/lib/app/accent_theme.dart`
- `app/lib/app/one_one_app.dart`
- `app/lib/features/identity/data/identity_repository.dart`
- `app/lib/features/identity/models/user_settings_record.dart`
- `app/lib/features/identity/ui/identity_home_screen.dart`
- `app/lib/features/identity/ui/settings_screen.dart`
- `app/lib/features/groups/ui/group_home_screen.dart`

## Manual Checks

1. Build and install the APK on two Android devices.
2. Confirm first launch signs in and lands on the One One home screen.
3. On Device A, create a group and create an invite.
4. On Device B, join with the invite code.
5. On both devices, tap Go online.
6. Confirm each device shows the other friend as Live.
7. Hold the mic button on Device A.
8. Confirm Device B hears Device A.
9. Release the mic button.
10. Confirm Device B can now hold and talk back.
11. Open Settings, change accent color, tap Save settings, and confirm the theme updates.
12. Restart the app and confirm the saved accent still loads.

## Verification

- `flutter analyze`: passed.

