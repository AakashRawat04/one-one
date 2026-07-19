# Nudge action and async processing contract

## Root cause found

The previous implementation ended after FCM delivery/playback. There was no
recipient response endpoint, no notification action receiver, and no state that
could turn a timed or voice nudge into a connection. Basic Push appeared to
"work" only because Android displayed it; it did not process acceptance either.

The codebase has no distinct event named `self_certification` or `voice_match`.
The implemented product mappings are:

- basic/self-cert style visible nudge: `nudge`
- timed 3/5/10-second nudge: `ring_nudge`
- recorded/voice flow: `voice_nudge`
- device registration renewal: native `onRegistered`

## Implemented pipeline

1. Backend creates `notificationEvents/{groupId}/{eventId}` for Push, Ring, or
   Voice and sends a high-priority data FCM containing `eventId`, `groupId`,
   sender details, and the authenticated response endpoint.
2. Android builds one actionable notification with Accept, Snooze, and
   Decline. Snooze opens inline Android choices for 5 or 15 minutes.
3. Accept starts One One through a `PendingIntent`; Flutter consumes the queued
   action, selects the event's group, calls the existing online/LiveKit logic,
   and writes `accept` only after the recipient is live. There is no second
   manual accept tap and the sender is not told to connect to a failed session.
4. Busy/Decline are handled by a non-exported native `BroadcastReceiver`. It
   obtains the persisted Firebase user's ID token and posts the response without
   opening Flutter.
5. Backend writes `nudgeResponses/{eventId}/{responderUserId}` and a status
   event, then sends a `nudge_response` data message to the sender.
6. When the sender's Flutter engine is alive, an accepted response is queued
   directly into the same group-selection/online path. If Android has killed
   the UI process, the response remains in Notification Center with a Connect
   action and is consumed when the sender opens it.
7. Native FCM registration renewal now signals Dart immediately when its engine
   is alive; startup/resume refresh remains the killed-process fallback.

## Platform boundary

Android does not permit an ordinary messaging app to launch an Activity
silently from the background. Full-screen intents are restricted to alarm/call
use cases and are not appropriate here. Therefore a completely killed sender
cannot be forced into Flutter/LiveKit invisibly when the recipient accepts. The
implemented reliable behavior is automatic connection for a live Flutter
engine and a persistent one-tap Connect notification for a killed sender.

## Verification checklist

- [ ] Push: foreground, background, and removed-from-Recents receiver sees all
  three actions.
- [ ] 3s Ring: audible for approximately three seconds; notification remains.
- [ ] 5s Ring: audible for approximately five seconds; notification remains.
- [ ] 10s Ring: audible for approximately ten seconds; notification remains.
- [ ] Voice: downloads, plays, ACKs `played`, remains actionable, and Storage
  cleanup occurs after recipient ACK.
- [ ] Accept: `nudgeResponses/.../action=accept`; recipient enters the event
  group and starts the normal connection flow without a manual in-app accept.
- [ ] Sender foreground/background process alive: receives
  `nudge_response=accept` and enters the same group connection path.
- [ ] Sender process killed: persistent response notification shows Connect;
  tapping it selects the group and connects.
- [ ] Snooze 5 min: app does not open; response contains `action=snooze`,
  `snoozeMinutes=5`, and a deadline about 300 seconds later.
- [ ] Snooze 15 min: app does not open; response contains `action=snooze`,
  `snoozeMinutes=15`, and a deadline about 900 seconds later.
- [ ] Decline: app does not open; response contains `action=decline`; sender is
  notified and neither user is auto-connected.
- [ ] Registration renewal: `[FCM-06]`, `[DART-06]`, and the normal device-sync
  logs appear; the latest identifier replaces the stale device record.
- [ ] Backend logs `NUDGE-RESPONSE-BE-01` with the matching event/action and FCM
  send counts.
