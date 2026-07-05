# Phase 7 Handoff: Push-To-Talk

## Status

Code generated. Manual install/build/runtime verification is pending.

## Implemented

- Firebase talk lock transaction at `/talkLocks/{groupId}`.
- One active speaker at a time.
- Lock expires after 60 seconds.
- Talk session records at `/talkSessions/{groupId}/{talkSessionId}`.
- Talk status events:
  - `talk_started`
  - `talk_stopped`
  - `talk_denied_busy`
- Hold-to-talk button on the online screen.
- Mic enable/disable commands sent to the existing foreground LiveKit task.
- Foreground task now handles:
  - `enable_mic`
  - `disable_mic`
- Online foreground service now starts with `mediaPlayback` and `microphone` service types.

## Files Added Or Changed

- `app/lib/features/talk/data/talk_repository.dart`
- `app/lib/features/talk/models/talk_session.dart`
- `app/lib/features/online/ui/online_screen.dart`
- `app/lib/features/online/data/online_repository.dart`
- `app/lib/phase1_spike/spike_keys.dart`
- `app/lib/phase1_spike/walkie_foreground_task.dart`
- `firebase/realtime-database.rules.json`

## Manual Checks

1. Device A and B join same group.
2. Device A goes online.
3. Device B goes online.
4. Device A holds `HOLD TO TALK`.
5. Confirm `/talkLocks/{groupId}` is created.
6. Confirm `/talkSessions/{groupId}/{talkSessionId}` is created.
7. Confirm Device B hears Device A.
8. While Device A is holding, Device B holds talk button.
9. Device B should see busy/denied.
10. Device A releases.
11. Confirm lock is removed.
12. Device B can now hold and talk.

## Notes

- This is the first phase where APK mic audio is expected to publish.
- If mic still does not publish, inspect foreground-service logs for `mic_failed`.
- Because the LiveKit room is owned by the foreground task, mic control is message-based between UI and service.
- Rules are permissive for testing and must be hardened before release.
