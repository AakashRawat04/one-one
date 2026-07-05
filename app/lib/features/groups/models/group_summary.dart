class GroupSummary {
  const GroupSummary({
    required this.groupId,
    required this.name,
    required this.ownerUserId,
    required this.livekitRoomName,
    required this.groupState,
  });

  final String groupId;
  final String name;
  final String ownerUserId;
  final String livekitRoomName;
  final String groupState;

  static GroupSummary fromJson(String groupId, Map<Object?, Object?> data) {
    return GroupSummary(
      groupId: groupId,
      name: data['name']?.toString() ?? 'Friends',
      ownerUserId: data['ownerUserId']?.toString() ?? '',
      livekitRoomName: data['livekitRoomName']?.toString() ?? 'group_$groupId',
      groupState: data['groupState']?.toString() ?? 'active',
    );
  }
}
