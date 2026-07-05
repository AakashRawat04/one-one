class OnlineSession {
  const OnlineSession({
    required this.groupId,
    required this.userId,
    required this.deviceId,
    required this.serviceSessionId,
    required this.livekitSessionId,
    required this.startedAt,
  });

  final String groupId;
  final String userId;
  final String deviceId;
  final String serviceSessionId;
  final String livekitSessionId;
  final int startedAt;
}
