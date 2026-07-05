import '../../../core/network/api_client.dart';
import '../../online/models/online_session.dart';
import '../models/notification_result.dart';

class NotificationRepository {
  NotificationRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<NotificationResult> sendFriendLive(OnlineSession session) async {
    final response = await _apiClient
        .postJson('/v1/groups/${session.groupId}/notifications/friend-live', {
          'deviceId': session.deviceId,
          'serviceSessionId': session.serviceSessionId,
          'livekitSessionId': session.livekitSessionId,
        });
    return NotificationResult.fromJson(response);
  }

  Future<NotificationResult> nudgeOne({
    required String groupId,
    required String targetUserId,
  }) async {
    final response = await _apiClient.postJson('/v1/groups/$groupId/nudges', {
      'targetScope': 'single_friend',
      'targetUserId': targetUserId,
    });
    return NotificationResult.fromJson(response);
  }

  Future<NotificationResult> nudgeAll({required String groupId}) async {
    final response = await _apiClient.postJson('/v1/groups/$groupId/nudges', {
      'targetScope': 'all_friends',
    });
    return NotificationResult.fromJson(response);
  }
}
