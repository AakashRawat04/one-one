import 'models/group_member_summary.dart';

bool groupHasServicePeer({
  required List<GroupMemberSummary> members,
  required String currentUserId,
}) {
  return members.any(
    (member) =>
        member.userId != currentUserId && member.memberState == 'active',
  );
}
