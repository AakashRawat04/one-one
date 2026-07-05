import 'package:firebase_database/firebase_database.dart';

import '../../../core/network/api_client.dart';
import '../models/group_invite_result.dart';
import '../models/group_member_summary.dart';
import '../models/group_summary.dart';

class GroupRepository {
  GroupRepository({ApiClient? apiClient, FirebaseDatabase? database})
    : _apiClient = apiClient ?? ApiClient(),
      _database = database ?? FirebaseDatabase.instance;

  final ApiClient _apiClient;
  final FirebaseDatabase _database;

  Future<GroupSummary> createGroup(String name) async {
    final response = await _apiClient.postJson('/v1/groups', {'name': name});
    final groupId = response['groupId'].toString();
    final snapshot = await _database.ref('groups/$groupId').get();

    if (snapshot.value is Map<Object?, Object?>) {
      return GroupSummary.fromJson(
        groupId,
        snapshot.value! as Map<Object?, Object?>,
      );
    }

    return GroupSummary(
      groupId: groupId,
      name: name,
      ownerUserId: '',
      livekitRoomName: response['livekitRoomName'].toString(),
      groupState: 'active',
    );
  }

  Future<GroupInviteResult> createInvite(String groupId) async {
    final response = await _apiClient.postJson('/v1/groups/$groupId/invites', {
      'maxUses': 3,
      'expiresInHours': 72,
    });
    return GroupInviteResult.fromJson(response);
  }

  Future<String> joinInvite(String inviteCode) async {
    final response = await _apiClient.postJson('/v1/invites/join', {
      'inviteCode': inviteCode,
    });
    return response['groupId'].toString();
  }

  Future<List<GroupSummary>> loadGroupsForUser(String userId) async {
    final membersSnapshot = await _database.ref('groupMembers').get();

    if (membersSnapshot.value is! Map<Object?, Object?>) {
      return const [];
    }

    final membersByGroup = membersSnapshot.value! as Map<Object?, Object?>;
    final groupIds = <String>[];

    for (final entry in membersByGroup.entries) {
      final groupId = entry.key.toString();
      final members = entry.value;

      if (members is! Map<Object?, Object?>) continue;

      final currentUserMember = members[userId];
      if (currentUserMember is! Map<Object?, Object?>) continue;

      if ((currentUserMember['memberState']?.toString() ?? 'active') ==
          'active') {
        groupIds.add(groupId);
      }
    }

    final groups = <GroupSummary>[];
    for (final groupId in groupIds) {
      final groupSnapshot = await _database.ref('groups/$groupId').get();
      if (groupSnapshot.value is Map<Object?, Object?>) {
        groups.add(
          GroupSummary.fromJson(
            groupId,
            groupSnapshot.value! as Map<Object?, Object?>,
          ),
        );
      }
    }

    return groups;
  }

  Future<List<GroupMemberSummary>> loadGroupMembers(String groupId) async {
    final snapshot = await _database.ref('groupMembers/$groupId').get();

    if (snapshot.value is! Map<Object?, Object?>) {
      return const [];
    }

    final members = snapshot.value! as Map<Object?, Object?>;
    final result = <GroupMemberSummary>[];

    for (final entry in members.entries) {
      final rawMember = entry.value;
      if (rawMember is! Map<Object?, Object?>) continue;

      final userId = entry.key.toString();
      final data = rawMember;
      final userSnapshot = await _database.ref('users/$userId').get();
      String displayName = userId;

      if (userSnapshot.value is Map<Object?, Object?>) {
        final userData = userSnapshot.value! as Map<Object?, Object?>;
        displayName = userData['displayName']?.toString() ?? userId;
      }

      result.add(
        GroupMemberSummary(
          userId: userId,
          displayName: displayName,
          role: data['role']?.toString() ?? 'member',
          memberState: data['memberState']?.toString() ?? 'active',
        ),
      );
    }

    return result;
  }
}
