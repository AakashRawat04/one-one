class TalkSession {
  const TalkSession({
    required this.groupId,
    required this.userId,
    required this.deviceId,
    required this.serviceSessionId,
    required this.livekitSessionId,
    required this.talkSessionId,
    required this.startedAt,
    required this.expiresAt,
  });

  final String groupId;
  final String userId;
  final String deviceId;
  final String serviceSessionId;
  final String livekitSessionId;
  final String talkSessionId;
  final int startedAt;
  final int expiresAt;
}
