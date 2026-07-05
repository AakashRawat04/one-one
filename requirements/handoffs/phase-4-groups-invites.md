# Phase 4 Handoff: Groups, Invites, Membership

## Status

Code generated. Manual dependency install/build/runtime verification is pending.

## Implemented

Backend:

- `POST /v1/groups`
- `POST /v1/groups/:groupId/invites`
- `POST /v1/invites/join`
- Firebase ID token validation.
- Active user validation.
- Active member validation for invite creation.
- Max 4 active members.
- Raw invite code returned once and only invite hash stored.
- Writes:
  - `/groups/{groupId}`
  - `/groupMembers/{groupId}/{userId}`
  - `/groupInvites/{inviteId}`
  - `/livekitRooms/{groupId}`
  - `/memberAvailability/{groupId}/{userId}`

Flutter:

- Authenticated backend API client.
- Group repository.
- Minimal group screen:
  - create group
  - join invite
  - create invite
  - list groups
  - list members

## Files Added Or Changed

- `backend/src/groups/groupService.ts`
- `backend/src/routes/groupRoutes.ts`
- `backend/src/app.ts`
- `app/lib/core/network/api_client.dart`
- `app/lib/features/groups/data/group_repository.dart`
- `app/lib/features/groups/models/group_summary.dart`
- `app/lib/features/groups/models/group_member_summary.dart`
- `app/lib/features/groups/models/group_invite_result.dart`
- `app/lib/features/groups/ui/group_home_screen.dart`
- `app/lib/features/identity/ui/identity_home_screen.dart`
- `firebase/realtime-database.rules.json`

## Manual Checks

After installing dependencies:

1. Create a user from the app.
2. Open `Groups`.
3. Create a group.
4. Create invite.
5. On another device/user, join with the invite code.
6. Confirm Firebase has group/member/availability rows.
7. Confirm raw invite code is not stored in `/groupInvites`.

## Notes

- The group list currently reads Firebase group membership data directly.
- Rules are MVP-friendly and should be tightened later once backend list endpoints exist.
- Notifications and push-to-talk are not part of Phase 4.
