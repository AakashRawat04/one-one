class GroupMemberSummary {
  const GroupMemberSummary({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.memberState,
  });

  final String userId;
  final String displayName;
  final String role;
  final String memberState;
}
