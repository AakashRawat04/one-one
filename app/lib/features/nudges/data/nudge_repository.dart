import 'package:flutter/foundation.dart';

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

  /// Direct-to-GCS upload via signed write URL, then backend finalize/FCM.
  Future<Map<String, dynamic>> sendVoice({
    required String groupId,
    required NudgeTarget target,
    required Uint8List audio,
    required int durationMs,
  }) async {
    final stopwatch = Stopwatch()..start();
    debugPrint(
      '[OneOneNudge][DART-01] Requesting voice nudge signed write URL '
      'audioBytes=${audio.length} durationMs=$durationMs '
      'targetScope=${target.targetScope}',
    );
    try {
      final upload = await _apiClient.postJson(
        '/v1/groups/$groupId/voice-nudges/uploads',
        {
          ...target.json,
          'durationMs': durationMs,
        },
      );
      final eventId = upload['notificationEventId']?.toString();
      final uploadUrl = upload['uploadUrl']?.toString();
      if (eventId == null ||
          eventId.isEmpty ||
          uploadUrl == null ||
          uploadUrl.isEmpty) {
        throw const ApiException(
          statusCode: 500,
          code: 'voice_nudge_upload_url_invalid',
          message: 'Backend did not return a usable signed write URL.',
        );
      }

      final requiredHeaders = <String, String>{};
      final rawHeaders = upload['requiredHeaders'];
      if (rawHeaders is Map) {
        rawHeaders.forEach((key, value) {
          requiredHeaders[key.toString()] = value.toString();
        });
      }
      if (!requiredHeaders.containsKey('content-type')) {
        requiredHeaders['content-type'] =
            upload['contentType']?.toString() ?? 'audio/mp4';
      }

      debugPrint(
        '[OneOneNudge][DART-01B] Uploading voice nudge directly to Cloud Storage '
        'eventId=$eventId audioBytes=${audio.length}',
      );
      await _apiClient.putBytesToUrl(
        uploadUrl,
        audio,
        headers: requiredHeaders,
      );

      debugPrint(
        '[OneOneNudge][DART-01C] Completing voice nudge after GCS upload '
        'eventId=$eventId elapsedMs=${stopwatch.elapsedMilliseconds}',
      );
      final response = await _apiClient.postJson(
        '/v1/groups/$groupId/voice-nudges/$eventId/complete',
        const {},
      );
      debugPrint(
        '[OneOneNudge][DART-02] Voice nudge upload accepted '
        'audioBytes=${audio.length} elapsedMs=${stopwatch.elapsedMilliseconds} '
        'eventId=${response['notificationEventId'] ?? eventId} '
        'targetDevices=${response['targetDevices']} '
        'uploadMode=signed_write_url',
      );
      return _requireAcceptedDelivery(response);
    } catch (error) {
      debugPrint(
        '[OneOneNudge][DART-E1] Voice nudge upload failed '
        'audioBytes=${audio.length} elapsedMs=${stopwatch.elapsedMilliseconds} '
        '${error.runtimeType}: $error',
      );
      rethrow;
    }
  }

  Future<Map<String, dynamic>> respond({
    required String groupId,
    required String eventId,
    required String action,
    int? snoozeMinutes,
  }) {
    if (!const {'accept', 'decline', 'snooze'}.contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    if (action == 'snooze' &&
        snoozeMinutes != 5 &&
        snoozeMinutes != 15) {
      throw ArgumentError.value(snoozeMinutes, 'snoozeMinutes');
    }
    return _apiClient.postJson(
      '/v1/groups/$groupId/nudges/$eventId/respond',
      {
        'action': action,
        if (action == 'snooze') 'snoozeMinutes': snoozeMinutes,
      },
    );
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
