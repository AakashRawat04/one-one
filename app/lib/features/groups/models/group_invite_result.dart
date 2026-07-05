class GroupInviteResult {
  const GroupInviteResult({
    required this.inviteId,
    required this.groupId,
    required this.inviteCode,
    required this.expiresAt,
  });

  final String inviteId;
  final String groupId;
  final String inviteCode;
  final int expiresAt;

  static GroupInviteResult fromJson(Map<String, dynamic> data) {
    return GroupInviteResult(
      inviteId: data['inviteId'].toString(),
      groupId: data['groupId'].toString(),
      inviteCode: data['inviteCode'].toString(),
      expiresAt: (data['expiresAt'] as num).toInt(),
    );
  }
}
