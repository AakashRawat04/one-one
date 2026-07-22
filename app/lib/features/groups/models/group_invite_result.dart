import '../../../app/app_config.dart';

class GroupInviteResult {
  const GroupInviteResult({
    required this.inviteId,
    required this.groupId,
    required this.inviteCode,
    required this.inviteUrl,
    required this.expiresAt,
  });

  final String inviteId;
  final String groupId;
  final String inviteCode;
  final String inviteUrl;
  final int expiresAt;

  static GroupInviteResult fromJson(Map<String, dynamic> data) {
    final inviteCode = data['inviteCode'].toString();
    final apiBaseUrl = AppConfig.apiBaseUrl.replaceFirst(RegExp(r'/$'), '');
    return GroupInviteResult(
      inviteId: data['inviteId'].toString(),
      groupId: data['groupId'].toString(),
      inviteCode: inviteCode,
      inviteUrl:
          data['inviteUrl']?.toString() ??
          '$apiBaseUrl/invite/${Uri.encodeComponent(inviteCode)}',
      expiresAt: (data['expiresAt'] as num).toInt(),
    );
  }
}
