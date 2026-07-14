import 'package:flutter_test/flutter_test.dart';
import 'package:one_one_app/features/groups/group_service_readiness.dart';
import 'package:one_one_app/features/groups/models/group_member_summary.dart';

void main() {
  const owner = GroupMemberSummary(
    userId: 'owner',
    displayName: 'Owner',
    role: 'owner',
    memberState: 'active',
  );

  test('service is unavailable to a group owner alone', () {
    expect(
      groupHasServicePeer(members: const [owner], currentUserId: 'owner'),
      isFalse,
    );
  });

  test('service becomes available when another active member joins', () {
    const friend = GroupMemberSummary(
      userId: 'friend',
      displayName: 'Friend',
      role: 'member',
      memberState: 'active',
    );

    expect(
      groupHasServicePeer(
        members: const [owner, friend],
        currentUserId: 'owner',
      ),
      isTrue,
    );
  });

  test('inactive members do not enable service', () {
    const inactiveFriend = GroupMemberSummary(
      userId: 'friend',
      displayName: 'Friend',
      role: 'member',
      memberState: 'removed',
    );

    expect(
      groupHasServicePeer(
        members: const [owner, inactiveFriend],
        currentUserId: 'owner',
      ),
      isFalse,
    );
  });
}
