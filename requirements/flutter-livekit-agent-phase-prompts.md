# Flutter + LiveKit Agent Phase Prompts

## Purpose

This document divides the whole project into sequential phases that can be assigned to sub-agents one after another.

Each agent should:

- Read the required docs before starting.
- Work only inside its assigned phase.
- Avoid rewriting earlier decisions unless a blocking issue is discovered.
- Leave a short handoff note for the next agent.
- Update requirements docs if implementation reality changes.

Primary source docs:

- `requirements/flutter-livekit-erd.md`
- `requirements/flutter-livekit-tech-plan.md`

## Global Rules For Every Agent

Use these rules in every phase prompt:

```txt
You are working on an Android-first Flutter walkie-talkie app using LiveKit, Firebase, FCM, and a small Node token backend.

Before making changes, read:
- requirements/flutter-livekit-erd.md
- requirements/flutter-livekit-tech-plan.md
- requirements/flutter-livekit-agent-phase-prompts.md

Preserve these MVP decisions:
- Android first.
- Flutter app.
- Self-hosted LiveKit.
- Firebase Anonymous Auth.
- Firebase Realtime Database.
- Firebase Cloud Messaging for friend-live and nudge notifications.
- One visible group in UI.
- Max 4 active members.
- One speaker at a time.
- Live audio only, no replay.
- Online mode requires persistent Android notification.
- Force-stop is unsupported for live receive.

Do not store raw audio.
Do not put LiveKit API secrets in the Flutter app.
Do not let the Flutter client send FCM directly.
Use backend APIs for LiveKit token generation, group creation, invite joins, friend-live notifications, and nudges.
```

## Phase Sequence

```txt
Phase 0: Repo/bootstrap audit and project scaffolding
Phase 1: Background audio spike
Phase 2: Infrastructure and backend foundation
Phase 3: Firebase data model, auth, profile, device registration
Phase 4: Group creation, invite, and membership
Phase 5: LiveKit online/away service integration
Phase 6: Friend-live and nudge notifications
Phase 7: Push-to-talk locking and audio publish
Phase 8: Minimal UI, settings, and vibrant themes
Phase 9: Reliability, permissions, diagnostics, and tests
Phase 10: End-to-end validation and release packaging
```

## Phase 0 Prompt: Repo Bootstrap

### Goal

Audit the repo and scaffold the project structure needed for Flutter app + Node backend if not already present.

### Prompt

```txt
You are Agent Phase 0: Repo/bootstrap audit and project scaffolding.

Read:
- requirements/flutter-livekit-erd.md
- requirements/flutter-livekit-tech-plan.md
- requirements/flutter-livekit-agent-phase-prompts.md

Your job:
1. Inspect the repository structure.
2. Determine whether a Flutter app already exists.
3. Determine whether a Node/TypeScript backend already exists.
4. If missing, scaffold:
   - Flutter app directory for Android-first client.
   - Node/TypeScript token API directory.
   - Basic README or docs showing how to run each.
5. Do not implement product features yet.
6. Do not configure real secrets.
7. Add `.env.example` files where needed.

Expected outputs:
- Clear repo structure for app and backend.
- Basic build/run instructions.
- Handoff note listing exact directories and commands.

Definition of done:
- Flutter project can run a default app or at least pass dependency resolution.
- Backend project can start a health endpoint or compile a placeholder service.
- No real secrets committed.
- Handoff note says whether Phase 1 can start.
```

### Handoff Expected

```txt
Directories created/confirmed:
- app path:
- backend path:

Commands:
- Flutter dependency install:
- Flutter run/check:
- Backend install:
- Backend run/check:

Known issues:
- ...
```

## Phase 1 Prompt: Background Audio Spike

### Goal

Prove the highest-risk behavior before full product build: LiveKit receive audio while app is backgrounded, locked, and UI-closed with foreground service active.

### Prompt

```txt
You are Agent Phase 1: Background audio spike.

Read the primary docs and Phase 0 handoff.

Your job:
1. Build the smallest possible Flutter Android spike using:
   - livekit_client
   - flutter_foreground_task or selected foreground service plugin
   - permission_handler
2. Connect to a test LiveKit room using temporary developer-provided token/config.
3. Start an Android foreground service from visible UI.
4. Keep a persistent notification visible while online.
5. Subscribe to remote LiveKit audio.
6. Write or simulate heartbeat state.
7. Test two real Android devices if available.

Do not build full auth, groups, invites, settings, or talk locking.

Acceptance checks:
- Receiver hears audio while app is foregrounded.
- Receiver hears audio while app is backgrounded.
- Receiver hears audio while screen is locked.
- Receiver heartbeat remains fresh while foreground service notification is active.
- Receiver becomes stale/offline when service is killed or heartbeat stops.
- Force-stop is documented as unsupported.

Expected outputs:
- Spike code.
- A short test report in requirements or docs.
- Recommendation: continue with Flutter service approach or fall back to minimal Android service bridge.

Definition of done:
- The team knows whether the LiveKit + Flutter foreground service approach is viable.
- Any native fallback need is documented before product features are built.
```

## Phase 2 Prompt: Infrastructure And Backend Foundation

### Goal

Create the deployable backend foundation for LiveKit tokens, FCM sends, and future group APIs.

### Prompt

```txt
You are Agent Phase 2: Infrastructure and backend foundation.

Read the primary docs and previous handoffs.

Your job:
1. Implement the Node/TypeScript backend foundation.
2. Add:
   - GET /healthz
   - Firebase Admin initialization
   - LiveKit server SDK initialization
   - FCM Admin SDK send-test utility or internal service
   - request validation structure
   - structured logging
   - environment config loader
3. Add Dockerfile and docker-compose service definition if backend directory exists.
4. Add `.env.example` with required variables.
5. Do not hardcode secrets.
6. Do not implement full product APIs except health and minimal test hooks unless required by Phase 1.

Expected outputs:
- Backend compiles.
- Health endpoint works.
- Firebase Admin can be initialized from env/config.
- LiveKit token generation utility exists but may not yet expose all endpoints.
- FCM send utility exists for later notification endpoints.

Definition of done:
- Backend has a clean service structure ready for product endpoints.
- Local run instructions are documented.
- Docker build path is documented or working.
```

## Phase 3 Prompt: Firebase Auth, Data Model, Profile, Device

### Goal

Implement app identity and core Firebase records.

### Prompt

```txt
You are Agent Phase 3: Firebase data model, auth, profile, and device registration.

Read the primary docs and previous handoffs.

Your job:
1. Add Firebase client setup to Flutter.
2. Implement anonymous auth.
3. Create/update:
   - /users/{userId}
   - /userDevices/{userId}/{deviceId}
   - /userSettings/{userId}
4. Capture:
   - display name
   - app version
   - install/device ID
   - FCM token
   - microphone permission state
   - notification permission state
   - battery optimization diagnostic if feasible
5. Add typed models for user, device, settings.
6. Add repository/controller layer consistent with project structure.

Do not implement group invite, online service, LiveKit connection, or push-to-talk yet.

Expected outputs:
- First-launch anonymous auth flow.
- Profile creation/update.
- Device registration.
- FCM token saved.
- Default settings saved, including accentColorKey.

Definition of done:
- A fresh install creates user, device, and settings records.
- Existing install reloads the same identity/device where possible.
- No backend secrets are in Flutter.
```

## Phase 4 Prompt: Groups, Invites, Membership

### Goal

Implement private group creation and invite join flow.

### Prompt

```txt
You are Agent Phase 4: Group creation, invite, and membership.

Read the primary docs and previous handoffs.

Your job:
1. Implement backend endpoints:
   - POST /v1/groups
   - POST /v1/groups/{groupId}/invites
   - POST /v1/invites/join
2. Enforce:
   - Firebase ID token verification
   - active user
   - max 4 active members
   - invite hash storage only
   - usedCount transaction
3. Write Firebase paths:
   - /groups/{groupId}
   - /groupMembers/{groupId}/{userId}
   - /groupInvites/{inviteId}
   - /livekitRooms/{groupId}
   - /memberAvailability/{groupId}/{userId}
4. Implement Flutter UI/controller for:
   - create group
   - create invite
   - join group by invite code
5. Keep UI minimal.

Do not implement online service, notifications, or push-to-talk yet.

Expected outputs:
- One user can create a group.
- Up to three friends can join via invite.
- Friend list can be loaded from group membership.

Definition of done:
- Four users can be active members of one group.
- Fifth active member is rejected.
- Raw invite code is not stored.
- LiveKit room mapping exists for the group.
```

## Phase 5 Prompt: LiveKit Online/Away Service

### Goal

Implement online/away mode with foreground service, LiveKit connection, availability, and heartbeat.

### Prompt

```txt
You are Agent Phase 5: LiveKit online/away service integration.

Read the primary docs and previous handoffs.

Your job:
1. Implement backend endpoint:
   - POST /v1/livekit/token
2. Validate:
   - Firebase ID token
   - active group membership
   - active user device
   - group LiveKit room mapping
3. Issue LiveKit token with:
   - roomJoin
   - canPublish
   - canSubscribe
   - canPublishData
4. Implement Flutter online flow:
   - request needed permissions
   - start foreground service from visible UI
   - create appServiceSession
   - request LiveKit token
   - connect LiveKit room
   - subscribe to remote audio
   - start heartbeat every 10 seconds
   - set staleAfterAt to now + 30 seconds
   - write memberAvailability
5. Implement away flow:
   - disable mic
   - release held lock if any
   - disconnect LiveKit
   - stop heartbeat
   - write desiredState/effectiveState away
   - stop foreground service

Do not implement friend-live FCM send yet unless Phase 6 starts.
Do not implement push-to-talk yet.

Expected outputs:
- Users can go online and away.
- Friends see live/away/stale/offline state.
- Foreground notification is visible while online.
- LiveKit connection is recorded in /livekitSessions.

Definition of done:
- effectiveState=live only when service is running, LiveKit connected, and heartbeat fresh.
- stale/offline appears within 30 seconds when heartbeat stops.
```

## Phase 6 Prompt: Friend-Live And Nudge Notifications

### Goal

Implement the non-negotiable notification behavior.

### Prompt

```txt
You are Agent Phase 6: Friend-live and nudge notifications.

Read the primary docs and previous handoffs.

Your job:
1. Implement backend endpoint:
   - POST /v1/groups/{groupId}/notifications/friend-live
2. Implement backend endpoint:
   - POST /v1/groups/{groupId}/nudges
3. Use Firebase Admin SDK to send FCM.
4. Enforce:
   - Firebase ID token verification
   - sender is active group member
   - target is active group member for single_friend nudge
   - sender excluded from recipients
   - friend-live sends only after sender effectiveState=live and canReceiveLiveAudio=true
   - friend-live dedupe during reconnect loops
   - nudge rate limits
5. Write:
   - /notificationEvents/{groupId}/{notificationEventId}
   - /notificationDeliveries/{notificationEventId}/{deliveryId}
   - relevant /statusEvents
6. Implement Flutter:
   - call friend-live endpoint after effective live state
   - add Nudge action to friend row
   - handle sent/rate-limited/error states
   - handle notification tap deep link to group screen
7. Configure notification channels:
   - walkie_service
   - walkie_alerts

Do not implement push-to-talk unless already started by next phase.

Expected outputs:
- Friends receive FCM when a user becomes effectively live.
- User can nudge one friend or all friends according to chosen UI.
- Nudges are rate-limited.
- Delivery attempts are stored.

Definition of done:
- Friend-live notification is sent after live state, not merely desired online.
- Manual nudge notification works.
- Client never sends FCM directly.
- Notification failures are visible in delivery records/logs.
```

## Phase 7 Prompt: Push-To-Talk

### Goal

Implement one-speaker-at-a-time push-to-talk using Firebase talk lock and LiveKit microphone publish.

### Prompt

```txt
You are Agent Phase 7: Push-to-talk locking and audio publish.

Read the primary docs and previous handoffs.

Your job:
1. Implement talk lock transaction at /talkLocks/{groupId}.
2. Success conditions:
   - no lock exists
   - existing lock expired
   - same holder/session already owns lock
3. Failure conditions:
   - another unexpired holder exists
   - current user is not live/listening
   - LiveKit session is not connected
4. Implement mic hold behavior:
   - touch down acquires lock
   - only after lock acquired, enable/publish microphone
   - touch up/cancel disables/unpublishes microphone
   - release lock
5. Write:
   - /talkSessions/{groupId}/{talkSessionId}
   - /statusEvents for talk_started, talk_stopped, talk_denied_busy
6. Update availability:
   - holder becomes talking
   - connected recipients become listening if subscribed
7. Handle crash/timeout recovery with expiresAt.

Expected outputs:
- Only one user can talk at a time.
- Other online users hear speaker.
- Busy user cannot publish mic.
- Release always disables mic.

Definition of done:
- Four-user manual test passes talk turn-taking.
- Expired lock recovers without manual DB cleanup.
- No raw audio is stored.
```

## Phase 8 Prompt: Minimal UI And Settings

### Goal

Build the intended app experience: minimal first screen, clear states, vibrant selectable colors.

### Prompt

```txt
You are Agent Phase 8: Minimal UI, settings, and vibrant themes.

Read the primary docs and previous handoffs.

Your job:
1. Implement/finish Home screen:
   - current user state
   - large hold-to-talk mic button
   - online/away control
   - friend status list
   - nudge action on friend rows
   - setup warning entry point
2. Implement Settings screen:
   - display name
   - accent color selector
   - haptics toggle
   - audio output preference
   - background reliability checklist
3. Use predefined vibrant accent keys:
   - coral
   - lime
   - sky
   - violet
   - amber
   - pink
   - teal
4. Keep first screen minimal.
5. Do not add feed, timeline, replay, or marketing screen.
6. Ensure text and controls fit on common Android screen sizes.

Expected outputs:
- First screen is usable for online/away, mic, friend state, nudge.
- Settings persist to /userSettings/{userId}.
- Theme updates based on accentColorKey.

Definition of done:
- A non-technical user can understand whether they are live and how to talk.
- Missing setup items are visible.
- UI has no clutter beyond MVP needs.
```

## Phase 9 Prompt: Reliability, Permissions, Diagnostics, Tests

### Goal

Harden behavior around permissions, stale states, notifications, service death, and network changes.

### Prompt

```txt
You are Agent Phase 9: Reliability, permissions, diagnostics, and tests.

Read the primary docs and previous handoffs.

Your job:
1. Add permission/setup checklist:
   - microphone permission
   - notification permission
   - foreground service notification active
   - battery optimization warning
   - network reachable
   - LiveKit reachable
2. Add diagnostics screen or debug panel:
   - userId/deviceId/groupId
   - desiredState/effectiveState
   - serviceState
   - livekitConnectionState
   - last heartbeat
   - last notification send result
3. Add tests:
   - availability state reducer
   - talk lock logic
   - nudge rate limits
   - friend-live dedupe
   - token endpoint validation
   - notification endpoint validation
4. Add Crashlytics keys/events if Crashlytics is configured.
5. Verify stale/offline behavior.
6. Verify FCM delivery records for success/failure.

Expected outputs:
- Common failure modes are visible and recoverable.
- Automated tests cover high-risk logic.
- Manual test checklist is updated.

Definition of done:
- App does not silently fail when permissions are missing.
- Stale/live state transitions are reliable.
- Notification rate limits and dedupe are tested.
```

## Phase 10 Prompt: End-To-End Validation And Release Packaging

### Goal

Validate full system with four users and prepare APK distribution.

### Prompt

```txt
You are Agent Phase 10: End-to-end validation and release packaging.

Read the primary docs and all previous handoffs.

Your job:
1. Run four-user manual acceptance test:
   - all join same group
   - all choose colors
   - each goes live
   - friend-live notifications arrive
   - nudge notifications work
   - A talks, B/C/D hear
   - B is denied while A talks
   - A releases, B can talk
   - C goes away and stops receiving
   - D closes UI with service active and still hears
   - D force-stops app and becomes stale/offline
2. Verify backend:
   - health endpoint
   - LiveKit token endpoint
   - notification endpoints
   - group/invite endpoints
3. Verify logs and delivery records.
4. Build release APK.
5. Document install steps for friends.
6. Document known Android limitations.

Expected outputs:
- End-to-end validation report.
- Release APK or build instructions.
- Known issues list.
- Final handoff summary.

Definition of done:
- The friend group can install and use the MVP.
- Non-negotiable live/nudge notifications are verified as FCM send attempts and tested on real devices.
- Unsupported force-stop behavior is documented.
```

## Suggested Agent Handoff Format

Each agent should leave this note when done:

```txt
Phase:
Status: complete / partial / blocked

Changed files:
- ...

Commands run:
- ...

Verification:
- ...

Known issues:
- ...

Next phase can start: yes/no

Notes for next agent:
- ...
```

## Dependency Map

```txt
Phase 0 -> all phases
Phase 1 -> Phase 5, Phase 7, Phase 10
Phase 2 -> Phase 4, Phase 5, Phase 6
Phase 3 -> Phase 4, Phase 5, Phase 6, Phase 8
Phase 4 -> Phase 5, Phase 6, Phase 7, Phase 8
Phase 5 -> Phase 6, Phase 7
Phase 6 -> Phase 8, Phase 9, Phase 10
Phase 7 -> Phase 8, Phase 9, Phase 10
Phase 8 -> Phase 10
Phase 9 -> Phase 10
```

## Parallelization Notes

The safest default is sequential execution.

Possible limited parallel work after Phase 2 and Phase 3 are stable:

```txt
Phase 4 backend group APIs and Phase 8 visual theme constants can be worked separately.
Phase 6 backend notification endpoints and Phase 8 UI nudge placement can be worked separately, but integration must happen after both complete.
Phase 9 tests can begin once each feature lands, but final reliability pass should happen near the end.
```

Do not parallelize:

```txt
Phase 1 background audio spike with the full online service implementation.
Phase 5 online/away service with Phase 7 push-to-talk until LiveKit connection state is stable.
Phase 6 notification integration before FCM token registration and backend Firebase Admin setup exist.
```

