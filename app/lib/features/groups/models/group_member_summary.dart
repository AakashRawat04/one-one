class GroupMemberSummary {
  const GroupMemberSummary({
    required this.userId,
    required this.displayName,
    required this.role,
    required this.memberState,
    this.profilePhotoUrl,
    this.profilePhotoBase64,
  });

  final String userId;
  final String displayName;
  final String role;
  final String memberState;
  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
}
