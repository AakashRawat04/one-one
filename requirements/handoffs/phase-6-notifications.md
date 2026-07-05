# Phase 6 Handoff: Friend-Live And Nudge Notifications

## Status

Code generated. Manual install/build/runtime verification is pending.

## Implemented

Backend:

- `POST /v1/groups/:groupId/notifications/friend-live`
- `POST /v1/groups/:groupId/nudges`
- Firebase ID token validation.
- Active group/user/member/device validation.
- Friend-live validation requires:
  - `desiredState=online`
  - `effectiveState=live`
  - `canReceiveLiveAudio=true`
- Friend-live dedupe window.
- Nudge rate limits:
  - same sender/recipient: 60 seconds
  - same sender/group: max 5 per 10 minutes
- FCM send via Firebase Admin SDK.
- Writes:
  - `/notificationEvents/{groupId}/{notificationEventId}`
  - `/notificationDeliveries/{notificationEventId}/{deliveryId}`
  - `/statusEvents/{groupId}/{eventId}`

Flutter:

- `NotificationRepository`.
- Friend-live API call after Phase 5 marks the user live.
- `Nudge all` in group screen.
- Per-member nudge button in group member list.

## Files Added Or Changed

- `backend/src/notifications/notificationService.ts`
- `backend/src/routes/notificationRoutes.ts`
- `backend/src/app.ts`
- `app/lib/features/notifications/data/notification_repository.dart`
- `app/lib/features/notifications/models/notification_result.dart`
- `app/lib/features/online/ui/online_screen.dart`
- `app/lib/features/groups/ui/group_home_screen.dart`
- `firebase/realtime-database.rules.json`

## Manual Checks

1. Install APK on two devices.
2. Both users sign in and join same group.
3. Confirm both `/userDevices/.../fcmToken` values are present.
4. Device A goes online.
5. Confirm backend creates `friend_live` notification event.
6. Device B should receive visible notification if Android notification permission is granted.
7. From group screen, Device A taps `Nudge all` or member nudge.
8. Device B should receive nudge notification.

## Notes

- Android 13+ requires notification runtime permission.
- Notification tap deep-link handling is not polished yet.
- Delivery is best-effort through FCM and depends on device/network/OS state.
