import 'package:firebase_database/firebase_database.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:uuid/uuid.dart';

import '../../../phase1_spike/spike_keys.dart';
import '../../online/models/online_session.dart';
import '../models/talk_session.dart';

class TalkRepository {
  TalkRepository({FirebaseDatabase? database})
    : _database = database ?? FirebaseDatabase.instance;

  final FirebaseDatabase _database;

  Future<TalkSession> startTalk(OnlineSession session) async {
    final now = _nowSeconds();
    final availability = await _database
        .ref('memberAvailability/${session.groupId}/${session.userId}')
        .get();
    final effectiveState = availability.child('effectiveState').val();
    final canReceive = availability.child('canReceiveLiveAudio').val() == true;

    if ((effectiveState != 'live' && effectiveState != 'listening') ||
        !canReceive) {
      throw TalkException('not_live', 'Go online before talking.');
    }

    final talkSessionId = const Uuid().v4();
    final expiresAt = now + 60;
    final lockRef = _database.ref('talkLocks/${session.groupId}');
    final result = await lockRef.runTransaction((current) {
      if (current is Map<Object?, Object?>) {
        final currentExpiresAt = _readInt(current['expiresAt']);
        final holderUserId = current['holderUserId']?.toString();
        final holderSessionId = current['serviceSessionId']?.toString();
        final sameHolder =
            holderUserId == session.userId &&
            holderSessionId == session.serviceSessionId;

        if (!sameHolder && currentExpiresAt > now) {
          return Transaction.abort();
        }
      }

      return Transaction.success({
        'groupId': session.groupId,
        'holderUserId': session.userId,
        'holderDeviceId': session.deviceId,
        'serviceSessionId': session.serviceSessionId,
        'livekitSessionId': session.livekitSessionId,
        'talkSessionId': talkSessionId,
        'startedAt': now,
        'expiresAt': expiresAt,
      });
    });

    if (!result.committed) {
      await _writeStatusEvent(session, 'talk_denied_busy', {
        'attemptedAt': now,
      });
      throw TalkException('busy', 'Someone else is talking.');
    }

    final talkSession = TalkSession(
      groupId: session.groupId,
      userId: session.userId,
      deviceId: session.deviceId,
      serviceSessionId: session.serviceSessionId,
      livekitSessionId: session.livekitSessionId,
      talkSessionId: talkSessionId,
      startedAt: now,
      expiresAt: expiresAt,
    );

    await _database.ref().update({
      'talkSessions/${session.groupId}/$talkSessionId': {
        'talkSessionId': talkSessionId,
        'groupId': session.groupId,
        'speakerUserId': session.userId,
        'speakerDeviceId': session.deviceId,
        'serviceSessionId': session.serviceSessionId,
        'livekitSessionId': session.livekitSessionId,
        'startedAt': now,
        'endedAt': null,
        'expiresAt': expiresAt,
        'endReason': null,
        'talkState': 'active',
      },
      'memberAvailability/${session.groupId}/${session.userId}/effectiveState':
          'talking',
      'memberAvailability/${session.groupId}/${session.userId}/updatedAt': now,
    });

    await _writeStatusEvent(session, 'talk_started', {
      'talkSessionId': talkSessionId,
    });

    FlutterForegroundTask.sendDataToTask({
      taskCommandKey: taskCommandEnableMic,
      taskTalkSessionIdKey: talkSessionId,
    });

    return talkSession;
  }

  Future<void> stopTalk(
    TalkSession talkSession, {
    String reason = 'released',
  }) async {
    final now = _nowSeconds();

    FlutterForegroundTask.sendDataToTask({
      taskCommandKey: taskCommandDisableMic,
      taskTalkSessionIdKey: talkSession.talkSessionId,
    });

    await _database.ref('talkLocks/${talkSession.groupId}').runTransaction((
      current,
    ) {
      if (current is Map<Object?, Object?> &&
          current['talkSessionId']?.toString() == talkSession.talkSessionId &&
          current['holderUserId']?.toString() == talkSession.userId) {
        return Transaction.success(null);
      }

      return Transaction.success(current);
    });

    await _database.ref().update({
      'talkSessions/${talkSession.groupId}/${talkSession.talkSessionId}/endedAt':
          now,
      'talkSessions/${talkSession.groupId}/${talkSession.talkSessionId}/endReason':
          reason,
      'talkSessions/${talkSession.groupId}/${talkSession.talkSessionId}/talkState':
          'completed',
      'memberAvailability/${talkSession.groupId}/${talkSession.userId}/effectiveState':
          'live',
      'memberAvailability/${talkSession.groupId}/${talkSession.userId}/updatedAt':
          now,
    });

    await _writeStatusEventFromTalk(talkSession, 'talk_stopped', {
      'talkSessionId': talkSession.talkSessionId,
      'reason': reason,
    });
  }

  Future<void> _writeStatusEvent(
    OnlineSession session,
    String eventType,
    Map<String, Object?> metadata,
  ) {
    return _writeStatusEventRaw(
      groupId: session.groupId,
      userId: session.userId,
      eventType: eventType,
      metadata: metadata,
    );
  }

  Future<void> _writeStatusEventFromTalk(
    TalkSession talkSession,
    String eventType,
    Map<String, Object?> metadata,
  ) {
    return _writeStatusEventRaw(
      groupId: talkSession.groupId,
      userId: talkSession.userId,
      eventType: eventType,
      metadata: metadata,
    );
  }

  Future<void> _writeStatusEventRaw({
    required String groupId,
    required String userId,
    required String eventType,
    required Map<String, Object?> metadata,
  }) async {
    final ref = _database.ref('statusEvents/$groupId').push();
    await ref.set({
      'eventId': ref.key,
      'groupId': groupId,
      'userId': userId,
      'eventType': eventType,
      'metadata': metadata,
      'createdAt': _nowSeconds(),
    });
  }

  int _nowSeconds() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}

class TalkException implements Exception {
  const TalkException(this.code, this.message);

  final String code;
  final String message;

  @override
  String toString() => message;
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
