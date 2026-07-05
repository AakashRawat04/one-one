# Phase 1 Handoff: Background Audio Spike

## Status

Code generated. Device/runtime verification is pending and should be performed manually.

## Scope Implemented

- Added LiveKit + foreground-service spike dependencies to the Flutter app.
- Replaced the generated counter app with a Phase 1 spike screen.
- Added a foreground-service task handler that attempts to connect to LiveKit from the service isolate.
- Added heartbeat/status messages from the service task back to the UI.
- Added Android permissions and foreground-service declaration.

## Files Added Or Changed

- `app/lib/main.dart`
- `app/lib/phase1_spike/phase1_spike_app.dart`
- `app/lib/phase1_spike/walkie_foreground_task.dart`
- `app/lib/phase1_spike/spike_keys.dart`
- `app/android/app/src/main/AndroidManifest.xml`
- `app/pubspec.yaml`
- `app/pubspec.lock`
- `app/test/widget_test.dart`
- `app/README.md`

## How To Manually Verify

Use two Android devices and a valid temporary LiveKit room token for each participant.

Receiver device:

1. Install/run the app.
2. Tap `Check permissions`.
3. Enter the LiveKit URL and receiver token.
4. Tap `Go online`.
5. Confirm the persistent `One One is online` notification appears.
6. Confirm the UI event log reaches `connected`.

Speaker device:

1. Join the same LiveKit room with a different participant token.
2. Publish microphone audio.

Acceptance checks:

- Receiver hears audio while app is foregrounded.
- Receiver hears audio while app is backgrounded.
- Receiver hears audio while the screen is locked.
- Receiver heartbeat continues while the foreground-service notification is active.
- Receiver stops being live when `Go away` is tapped or the service is killed.
- Force-stop remains unsupported.

## Important Notes

- The spike starts the foreground service with `mediaPlayback` type only because Phase 1 is receive-audio focused.
- `RECORD_AUDIO` and `FOREGROUND_SERVICE_MICROPHONE` are declared for later push-to-talk work, but the Phase 1 service keeps the local mic muted.
- LiveKit URL/token are entered manually for the spike. Phase 2/5 should replace this with backend-issued tokens.
- No Firebase heartbeat writes are implemented yet; the spike simulates heartbeat locally through service-to-UI messages.

## Verification Already Done

- `flutter analyze`: passed before this handoff was written.
- `flutter test`: passed before this handoff was written.
- An Android debug build was attempted, but stopped after the user clarified that runtime/build execution should be handled manually.

## Next Recommendation

Manually verify this spike on real Android devices before Phase 2/5. If LiveKit cannot stay connected from the Flutter foreground-service task isolate while the UI is closed, switch to a minimal native Android service bridge before building full product features.
