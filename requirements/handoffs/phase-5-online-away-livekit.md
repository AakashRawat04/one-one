# Phase 5 Handoff: Online/Away LiveKit Integration

## Status

Code generated. Manual install/build/runtime verification is pending.

## Important Clarification

Phase 5 is not the final phase.

Remaining product phases:

- Phase 6: friend-live and nudge notifications.
- Phase 7: push-to-talk locking and microphone publish.
- Phase 8: final minimal UI/settings/theme.
- Phase 9: reliability, diagnostics, permissions, tests.
- Phase 10: end-to-end validation and release packaging.

## Implemented

Backend:

- `POST /v1/livekit/token`
- Validates:
  - Firebase ID token
  - active user
  - active group
  - active group member
  - active user device
  - LiveKit room mapping
- Issues LiveKit token with room join, publish, subscribe, and data grants.
- Writes `/livekitTokenIssuances/{tokenId}`.

Flutter:

- Online repository.
- Online screen reachable from selected group.
- Requests notification/microphone/battery reliability permissions.
- Creates:
  - `/appServiceSessions/{serviceSessionId}`
  - `/livekitSessions/{livekitSessionId}`
  - `/memberAvailability/{groupId}/{userId}`
- Requests backend LiveKit token.
- Stores token/url for foreground-service LiveKit connection.
- Starts foreground service using the Phase 1 task handler.
- Marks availability live after service reports LiveKit `connected`.
- Writes heartbeat every 10 seconds while the screen/controller is alive.
- Implements away flow and updates Firebase state.

## Files Added Or Changed

- `backend/src/livekit/liveKitTokenService.ts`
- `backend/src/routes/liveKitRoutes.ts`
- `backend/src/app.ts`
- `app/lib/features/online/data/online_repository.dart`
- `app/lib/features/online/models/livekit_token_response.dart`
- `app/lib/features/online/models/online_session.dart`
- `app/lib/features/online/ui/online_screen.dart`
- `app/lib/features/groups/ui/group_home_screen.dart`
- `firebase/realtime-database.rules.json`

## Manual Checks

Backend:

```sh
cd backend
npm install
npm run build
npm start
```

App:

```sh
cd app
flutter pub get
flutter run --dart-define=ONE_ONE_API_BASE_URL=http://<your-backend-host>:8080
```

Two-device flow:

1. Device A creates a group.
2. Device A creates invite.
3. Device B joins invite.
4. Device A opens group and taps `Online mode`.
5. Device A taps `Go online`.
6. Confirm foreground notification appears.
7. Confirm Firebase availability becomes `effectiveState=live`.
8. Confirm `/appServiceSessions`, `/livekitSessions`, and `/livekitTokenIssuances` are created.
9. Tap `Go away`.
10. Confirm availability becomes `away`.

## Known Gaps

- Heartbeat writing is currently app-controller based. The foreground task keeps the LiveKit connection alive, but a stronger Phase 9 hardening pass should move Firebase heartbeat writes fully into the service/native layer if Android testing shows UI-isolate heartbeat stops when the UI is closed.
- Friend-live notification is not sent yet. That is Phase 6.
- Push-to-talk microphone publish is not implemented yet. That is Phase 7.
- One-speaker talk locking is not implemented yet. That is Phase 7.
