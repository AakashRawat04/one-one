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
  }) async {
    final response = await _apiClient.postJson(
      '/v1/groups/$groupId/nudges',
      target.json,
    );
    return _requireAcceptedDelivery(response);
  }

  Future<Map<String, dynamic>> sendRing({
    required String groupId,
    required NudgeTarget target,
    required int durationSeconds,
  }) async {
    if (durationSeconds != 3 &&
        durationSeconds != 5 &&
        durationSeconds != 10) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    final response = await _apiClient.postJson(
      '/v1/groups/$groupId/ring-nudges',
      {
        ...target.json,
        'durationSeconds': durationSeconds,
      },
    );
    return _requireAcceptedDelivery(response);
  }

  Future<Map<String, dynamic>> sendVoice({
    required String groupId,
    required NudgeTarget target,
    required Uint8List audio,
    required int durationMs,
  }) async {
    final query = Uri(queryParameters: target.query).query;
    final response = await _apiClient.postBytes(
      '/v1/groups/$groupId/voice-nudges?$query',
      audio,
      contentType: 'audio/mp4',
      headers: {'x-voice-duration-ms': '$durationMs'},
    );
    return _requireAcceptedDelivery(response);
  }

  Map<String, dynamic> _requireAcceptedDelivery(
    Map<String, dynamic> response,
  ) {
    final recipientUsers = _readCount(response['recipientUsers']);
    final targetDevices = _readCount(response['targetDevices']);
    final sent = _readCount(response['sent']);
    if (recipientUsers == 0) {
      throw const NudgeDeliveryException(
        'No active friends were found for this nudge.',
      );
    }
    if (targetDevices == 0) {
      throw const NudgeDeliveryException(
        'The recipient has no registered Android device. Ask them to open One One once.',
      );
    }
    if (sent == 0) {
      throw const NudgeDeliveryException(
        'FCM rejected every target device. Check the backend FCM-BE-W1 error code.',
      );
    }
    return response;
  }
}

class NudgeDeliveryException implements Exception {
  const NudgeDeliveryException(this.message);

  final String message;

  @override
  String toString() => message;
}

int _readCount(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
