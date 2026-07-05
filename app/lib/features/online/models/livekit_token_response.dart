class LiveKitTokenResponse {
  const LiveKitTokenResponse({
    required this.serverUrl,
    required this.roomName,
    required this.participantIdentity,
    required this.participantName,
    required this.token,
    required this.expiresAt,
  });

  final String serverUrl;
  final String roomName;
  final String participantIdentity;
  final String participantName;
  final String token;
  final int expiresAt;

  static LiveKitTokenResponse fromJson(Map<String, dynamic> data) {
    return LiveKitTokenResponse(
      serverUrl: data['serverUrl'].toString(),
      roomName: data['roomName'].toString(),
      participantIdentity: data['participantIdentity'].toString(),
      participantName: data['participantName'].toString(),
      token: data['token'].toString(),
      expiresAt: (data['expiresAt'] as num).toInt(),
    );
  }
}
