# Firebase Setup

Phase 3 uses Firebase Authentication, Realtime Database, and Cloud Messaging.
Phase 4/5 add group reads and own-session availability writes.

## Android Config

Place the Firebase Android config file here before building the app:

```txt
app/android/app/google-services.json
```

Use Android package name:

```txt
app.oneone.one_one_app
```

## Realtime Database Rules

Phase 3 rules are in:

```txt
firebase/realtime-database.rules.json
```

They allow each authenticated anonymous user to read/write:

- `/users/{ownUserId}`
- `/userDevices/{ownUserId}`
- `/userSettings/{ownUserId}`
- `/memberAvailability/{groupId}/{ownUserId}`
- own `/appServiceSessions/{sessionId}`
- own `/livekitSessions/{sessionId}`
- talk lock/session/status paths for Phase 7 testing

Authenticated users can read group/member/user display state for the MVP.
Invite writes, group writes, LiveKit room writes, and notification writes are backend-owned.

Phase 7 talk-lock rules are permissive for testing. Harden them before release.
