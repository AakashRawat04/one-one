import 'package:one_one_app/one_one.dart';

class NudgeRepository {
  NudgeRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  final ApiClient _apiClient;

  Future<Map<String, dynamic>> sendPush({
    required String groupId,
    required NudgeTarget target,
  }) async {
    // 1. POST push nudge
    final response = await _apiClient.postJson(
      '/v1/groups/$groupId/nudges',
      target.json,
    );
    final result = _requireAcceptedDelivery(
      response,
      groupId: groupId,
      kind: 'nudge',
    );
    // 2. Log + analytics
    LogManager.log(
      LogLevel.info,
      'NudgeService',
      'Nudge sent kind=push targetScope=${target.targetScope} '
          'eventId=${result['notificationEventId'] ?? '-'}',
      groupId: groupId,
    );
    await AnalyticsService.logNudgeSent(
      groupId: groupId,
      kind: 'push',
      targetScope: target.targetScope,
    );
    return result;
  }

  Future<Map<String, dynamic>> sendRing({
    required String groupId,
    required NudgeTarget target,
    required int durationSeconds,
  }) async {
    if (durationSeconds != 3 && durationSeconds != 6 && durationSeconds != 9) {
      throw ArgumentError.value(durationSeconds, 'durationSeconds');
    }
    // 1. POST ring nudge
    final response = await _apiClient.postJson(
      '/v1/groups/$groupId/ring-nudges',
      {...target.json, 'durationSeconds': durationSeconds},
    );
    final result = _requireAcceptedDelivery(
      response,
      groupId: groupId,
      kind: 'ring_nudge',
    );
    LogManager.log(
      LogLevel.info,
      'NudgeService',
      'Nudge sent kind=ring durationSeconds=$durationSeconds '
          'targetScope=${target.targetScope} '
          'eventId=${result['notificationEventId'] ?? '-'}',
      groupId: groupId,
    );
    await AnalyticsService.logNudgeSent(
      groupId: groupId,
      kind: 'ring',
      targetScope: target.targetScope,
      durationMs: durationSeconds * 1000,
    );
    return result;
  }

  /// Reserves a signed GCS write URL so the recorder flush can overlap the
  /// first network hop. [sendVoice] will retry this if [initiatedUpload] is
  /// omitted or unusable.
  Future<Map<String, dynamic>> initiateVoiceUpload({
    required String groupId,
    required NudgeTarget target,
    required int durationMs,
  }) {
    return _apiClient.postJson('/v1/groups/$groupId/voice-nudges/uploads', {
      ...target.json,
      'durationMs': durationMs,
    });
  }

  /// Direct-to-GCS upload via signed write URL, then backend finalize/FCM.
  Future<Map<String, dynamic>> sendVoice({
    required String groupId,
    required NudgeTarget target,
    required Uint8List audio,
    required int durationMs,
    Map<String, dynamic>? initiatedUpload,
  }) async {
    final flowWatch = Stopwatch()..start();
    final expectedBytes = VoiceNudgeAudio.expectedPayloadBytes(durationMs);
    debugPrint(
      '[OneOneNudge][DART-01] Requesting voice nudge signed write URL '
      'audioBytes=${audio.length} expectedBytes=$expectedBytes '
      'legacyBytes=${VoiceNudgeAudio.legacyPayloadBytes(durationMs)} '
      'durationMs=$durationMs bitRate=${VoiceNudgeAudio.bitRate} '
      'sampleRate=${VoiceNudgeAudio.sampleRate} '
      'targetScope=${target.targetScope}',
    );
    try {
      // 1. Reuse reserved upload URL, or request one
      final reservedUpload = _usableVoiceUpload(initiatedUpload);
      final reserved = reservedUpload != null;
      final upload =
          reservedUpload ??
          await initiateVoiceUpload(
            groupId: groupId,
            target: target,
            durationMs: durationMs,
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
            upload['contentType']?.toString() ?? VoiceNudgeAudio.contentType;
      }

      debugPrint(
        '[OneOneNudge][DART-01B] Uploading voice nudge directly to Cloud Storage '
        'eventId=$eventId audioBytes=${audio.length}',
      );
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'VOICE_NUDGE_UPLOAD_START nudgeId=$eventId bytes=${audio.length} '
            'durationMs=$durationMs reservedUrl=$reserved',
        groupId: groupId,
      );
      // 2. PUT audio to GCS
      final uploadWatch = Stopwatch()..start();
      await _apiClient.putBytesToUrl(
        uploadUrl,
        audio,
        headers: requiredHeaders,
      );
      final uploadMs = uploadWatch.elapsedMilliseconds;
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'VOICE_NUDGE_UPLOAD_END nudgeId=$eventId bytes=${audio.length} '
            'uploadMs=$uploadMs',
        groupId: groupId,
      );

      debugPrint(
        '[OneOneNudge][DART-01C] Completing voice nudge after GCS upload '
        'eventId=$eventId elapsedMs=${flowWatch.elapsedMilliseconds}',
      );
      final uploadTicket = upload['uploadTicket']?.toString();
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'VOICE_NUDGE_SEND_START nudgeId=$eventId',
        groupId: groupId,
      );
      // 3. Backend finalize + FCM
      final fcmWatch = Stopwatch()..start();
      final response = await _apiClient
          .postJson('/v1/groups/$groupId/voice-nudges/$eventId/complete', {
            if (uploadTicket != null && uploadTicket.isNotEmpty)
              'uploadTicket': uploadTicket,
          });
      debugPrint(
        '[OneOneNudge][DART-02] Voice nudge upload accepted '
        'audioBytes=${audio.length} elapsedMs=${flowWatch.elapsedMilliseconds} '
        'eventId=${response['notificationEventId'] ?? eventId} '
        'targetDevices=${response['targetDevices']} '
        'uploadMode=signed_write_url',
      );
      final result = _requireAcceptedDelivery(
        response,
        groupId: groupId,
        kind: 'voice_nudge',
      );
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'VOICE_NUDGE_SEND_ACK nudgeId=${result['notificationEventId'] ?? eventId} '
            'sendMs=${fcmWatch.elapsedMilliseconds} '
            'sent=${result['sent'] ?? '-'} '
            'targetDevices=${result['targetDevices'] ?? '-'}',
        groupId: groupId,
      );
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'Nudge sent kind=voice bytes=${audio.length} durationMs=$durationMs '
            'eventId=${result['notificationEventId'] ?? eventId} '
            'uploadMs=$uploadMs flowMs=${flowWatch.elapsedMilliseconds}',
        groupId: groupId,
      );
      await AnalyticsService.logNudgeSent(
        groupId: groupId,
        kind: 'voice',
        targetScope: target.targetScope,
        audioBytes: audio.length,
        durationMs: durationMs,
      );
      await CrashlyticsService.log(
        'voice_nudge_sent bytes=${audio.length} ms=$durationMs',
      );
      return result;
    } catch (error, stack) {
      debugPrint(
        '[OneOneNudge][DART-E1] Voice nudge upload failed '
        'audioBytes=${audio.length} elapsedMs=${flowWatch.elapsedMilliseconds} '
        '${error.runtimeType}: $error',
      );
      final reachability = NudgeReachability.fromSendError(error);
      unawaited(
        AnalyticsService.logNudgeFailed(
          groupId: groupId,
          kind: 'voice',
          failureReason: reachability,
          deliveryMethod: 'fcm',
        ),
      );
      OperationalLog.record(
        event: OperationalLog.eventNudgeFailed,
        eventType: OperationalLog.eventTypeNudge,
        status: reachability,
        error: error.toString(),
        groupId: groupId,
        level: LogLevel.error,
        debugMetadata: {
          'nudge_type': 'voice',
          'send_status': 'failed',
          'checkpoint': 'voice_nudge_upload',
          'audio_bytes': audio.length,
        },
      );
      LogManager.log(
        LogLevel.error,
        'NudgeService',
        'Nudge not delivered: network error. Voice send failed: $error',
        groupId: groupId,
      );
      if (error is! NudgeDeliveryException) {
        await CrashlyticsService.recordNudgeFailure(
          error: error,
          stack: stack,
          failureReason: NudgeFailureReason.unknown,
          groupId: groupId,
          extras: {'checkpoint': 'voice_nudge_upload'},
        );
      }
      rethrow;
    }
  }

  Future<Map<String, dynamic>> respond({
    required String groupId,
    required String eventId,
    required String action,
    int? snoozeMinutes,
  }) async {
    if (!const {'accept', 'decline', 'snooze'}.contains(action)) {
      throw ArgumentError.value(action, 'action');
    }
    if (action == 'snooze' && snoozeMinutes != 5 && snoozeMinutes != 15) {
      throw ArgumentError.value(snoozeMinutes, 'snoozeMinutes');
    }
    final response = await _apiClient.postJson(
      '/v1/groups/$groupId/nudges/$eventId/respond',
      {
        'action': action,
        if (action == 'snooze') 'snoozeMinutes': snoozeMinutes,
      },
    );
    await AnalyticsService.logNudgeResponded(
      groupId: groupId,
      action: action,
      snoozeMinutes: snoozeMinutes,
    );
    return response;
  }

  Map<String, dynamic> _requireAcceptedDelivery(
    Map<String, dynamic> response, {
    String? groupId,
    String? kind,
  }) {
    final nudgeType = switch (kind) {
      'ring_nudge' => 'ring',
      'voice_nudge' => 'voice',
      'nudge' => 'push',
      _ => kind,
    };
    final recipientUsers = _readCount(response['recipientUsers']);
    final targetDevices = _readCount(response['targetDevices']);
    final sent = _readCount(response['sent']);
    if (recipientUsers == 0) {
      unawaited(
        AnalyticsService.logNudgeFailed(
          groupId: groupId ?? '',
          kind: nudgeType,
          failureReason: NudgeReachability.deviceUnreachable,
          deliveryMethod: 'fcm',
        ),
      );
      OperationalLog.record(
        event: OperationalLog.eventNudgeFailed,
        eventType: OperationalLog.eventTypeNudge,
        status: NudgeReachability.deviceUnreachable,
        error: 'no_recipients',
        groupId: groupId,
        level: LogLevel.warn,
        debugMetadata: {
          'nudge_type': kind,
          'send_status': 'failed',
          'unreachable_reason': 'no_active_friends',
        },
      );
      throw const NudgeDeliveryException(
        'No active friends were found for this nudge.',
        code: NudgeDeliveryFailureCode.noRecipients,
      );
    }
    if (targetDevices == 0) {
      unawaited(
        AnalyticsService.logNudgeFailed(
          groupId: groupId ?? '',
          kind: nudgeType,
          failureReason: NudgeReachability.deviceUnreachable,
          deliveryMethod: 'fcm',
        ),
      );
      OperationalLog.record(
        event: OperationalLog.eventNudgeFailed,
        eventType: OperationalLog.eventTypeNudge,
        status: NudgeReachability.deviceUnreachable,
        error: 'no_registered_device',
        groupId: groupId,
        level: LogLevel.warn,
        debugMetadata: {
          'nudge_type': kind,
          'send_status': 'failed',
          'unreachable_reason': 'no_registered_device',
          'likely_cause': 'wrong_account_or_missing_fcm',
        },
      );
      throw const NudgeDeliveryException(
        UserFacingCopy.recipientDeviceUnavailable,
        code: NudgeDeliveryFailureCode.noRegisteredDevice,
      );
    }
    if (sent == 0) {
      unawaited(
        AnalyticsService.logNudgeFailed(
          groupId: groupId ?? '',
          kind: nudgeType,
          failureReason: NudgeReachability.deviceUnreachable,
          deliveryMethod: 'fcm',
        ),
      );
      OperationalLog.record(
        event: OperationalLog.eventNudgeFailed,
        eventType: OperationalLog.eventTypeNudge,
        status: NudgeReachability.deviceUnreachable,
        error: 'fcm_not_delivered',
        groupId: groupId,
        nudgeId: response['notificationEventId']?.toString(),
        level: LogLevel.error,
        debugMetadata: {
          'nudge_type': kind,
          'send_status': 'failed',
          'delivery_status': 'fcm_rejected',
          'recipient_users': recipientUsers,
          'target_devices': targetDevices,
          'unreachable_reason': 'fcm_rejected',
          'likely_cause': 'wrong_account_or_stale_fcm',
        },
      );
      unawaited(
        CrashlyticsService.recordFcmNotificationHandlingFailure(
          error: StateError(
            'FCM rejected every target device (FCM-BE-W1) '
            'kind=${kind ?? '-'} groupId=${groupId ?? '-'}',
          ),
          worker: 'FCM-BE-W1',
          groupId: groupId,
          eventId: response['notificationEventId']?.toString(),
          kind: nudgeType,
        ),
      );
      throw const NudgeDeliveryException(
        UserFacingCopy.notificationDeliveryFailure,
        code: NudgeDeliveryFailureCode.fcmNotDelivered,
      );
    }
    return response;
  }
}

abstract final class NudgeDeliveryFailureCode {
  static const noRecipients = 'no_recipients';
  static const noRegisteredDevice = 'no_registered_device';
  static const fcmNotDelivered = 'fcm_not_delivered';
}

class NudgeDeliveryException implements Exception {
  const NudgeDeliveryException(this.message, {this.code});

  final String message;
  final String? code;

  @override
  String toString() => message;
}

class NudgeResult {
  const NudgeResult({
    required this.totalRecipients,
    required this.failedCount,
    this.successRecipientIds = const [],
    this.failedRecipientIds = const [],
  });

  factory NudgeResult.fromSendResponse(
    Map<String, dynamic> response,
    List<String> intendedRecipientIds,
  ) {
    final total = intendedRecipientIds.length;
    final failedCount = _readCount(response['failed']).clamp(0, total);

    if (failedCount == 0) {
      return NudgeResult(
        totalRecipients: total,
        failedCount: 0,
        successRecipientIds: intendedRecipientIds,
      );
    }
    if (failedCount >= total) {
      return NudgeResult(
        totalRecipients: total,
        failedCount: total,
        failedRecipientIds: intendedRecipientIds,
      );
    }
    return NudgeResult(totalRecipients: total, failedCount: failedCount);
  }

  final int totalRecipients;
  final int failedCount;
  final List<String> successRecipientIds;
  final List<String> failedRecipientIds;

  int get successCount => totalRecipients - failedCount;
  bool get isFullSuccess => failedCount == 0;
  bool get isFullFailure =>
      totalRecipients > 0 && failedCount >= totalRecipients;
  bool get isPartialFailure => failedCount > 0 && failedCount < totalRecipients;
}

int _readCount(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

Map<String, dynamic>? _usableVoiceUpload(Map<String, dynamic>? upload) {
  if (upload == null) return null;
  final eventId = upload['notificationEventId']?.toString();
  final uploadUrl = upload['uploadUrl']?.toString();
  if (eventId == null ||
      eventId.isEmpty ||
      uploadUrl == null ||
      uploadUrl.isEmpty) {
    return null;
  }
  return upload;
}
