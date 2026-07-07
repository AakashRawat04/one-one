class OnlineSession {
  const OnlineSession({
    required this.groupId,
    required this.userId,
    required this.deviceId,
    required this.serviceSessionId,
    required this.livekitSessionId,
    required this.livekitServerUrl,
    required this.livekitToken,
    required this.livekitRoomName,
    required this.participantIdentity,
    required this.startedAt,
  });

  final String groupId;
  final String userId;
  final String deviceId;
  final String serviceSessionId;
  final String livekitSessionId;
  final String livekitServerUrl;
  final String livekitToken;
  final String livekitRoomName;
  final String participantIdentity;
  final int startedAt;
}
