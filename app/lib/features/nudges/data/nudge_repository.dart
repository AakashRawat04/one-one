import 'dart:typed_data';

import '../../../core/network/api_client.dart';

class NudgeTarget {
  const NudgeTarget.allFriends()
    : targetScope = 'all_friends',
      targetUserId = null;

  const NudgeTarget.singleFriend(this.targetUserId)
    : targetScope = 'single_friend';

  final String targetScope;
  final String? targetUserId;

  Map<String, Object?> get json {
    final result = <String, Object?>{'targetScope': targetScope};
    final userId = targetUserId;
    if (userId != null) result['targetUserId'] = userId;
    return result;
  }

  Map<String, String> get query {
    final result = <String, String>{'targetScope': targetScope};
    final userId = targetUserId;
    if (userId != null) result['targetUserId'] = userId;
    return result;
  }
}

class NudgeRepository {
  NudgeRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> sendPush({
    required String groupId,
    required NudgeTarget target,
  }) {
    return _apiClient.postJson('/v1/groups/$groupId/nudges', target.json);
  }

  Future<Map<String, dynamic>> sendRing({
    required String groupId,
    required NudgeTarget target,
    required int durationSeconds,
  }) {
    if (durationSeconds != 3 &&
        durationSeconds != 5 &&
        durationSeconds != 10) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    return _apiClient.postJson('/v1/groups/$groupId/ring-nudges', {
      ...target.json,
      'durationSeconds': durationSeconds,
    });
  }

  Future<Map<String, dynamic>> sendVoice({
    required String groupId,
    required NudgeTarget target,
    required Uint8List audio,
    required int durationMs,
  }) {
    final query = Uri(queryParameters: target.query).query;
    return _apiClient.postBytes(
      '/v1/groups/$groupId/voice-nudges?$query',
      audio,
      contentType: 'audio/mp4',
      headers: {'x-voice-duration-ms': '$durationMs'},
    );
  }
}
