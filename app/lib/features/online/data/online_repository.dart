import 'package:firebase_database/firebase_database.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firebase/app_database.dart';
import '../../../core/network/api_client.dart';
import '../../groups/models/group_summary.dart';
import '../../identity/models/identity_session.dart';
import '../models/livekit_token_response.dart';
import '../models/member_availability.dart';
import '../models/online_session.dart';

class OnlineRepository {
  OnlineRepository({ApiClient? apiClient, FirebaseDatabase? database})
    : _apiClient = apiClient ?? ApiClient(),
      _database = database ?? AppDatabase.instance();

  final ApiClient _apiClient;
  final FirebaseDatabase _database;

  Future<OnlineSession> goOnline({
    required IdentitySession identity,
    required GroupSummary group,
  }) async {
    await _requestOnlinePermissions();

    final now = _nowSeconds();
    final serviceSessionId = const Uuid().v4();
    final livekitSessionId = const Uuid().v4();
    final token = await _requestLiveKitToken(
      groupId: group.groupId,
      deviceId: identity.deviceId,
      serviceSessionId: serviceSessionId,
      livekitSessionId: livekitSessionId,
    );

    final session = OnlineSession(
      groupId: group.groupId,
      userId: identity.userId,
      deviceId: identity.deviceId,
      serviceSessionId: serviceSessionId,
      livekitSessionId: livekitSessionId,
      livekitServerUrl: token.serverUrl,
      livekitToken: token.token,
      livekitRoomName: token.roomName,
      participantIdentity: token.participantIdentity,
      startedAt: now,
    );

    await _database.ref().update({
      'appServiceSessions/$serviceSessionId': {
        'groupId': group.groupId,
        'userId': identity.userId,
        'deviceId': identity.deviceId,
        'serviceState': 'starting',
        'startReason': 'user_online',
        'stopReason': null,
        'startedAt': now,
        'stoppedAt': null,
        'lastHeartbeatAt': now,
      },
      'livekitSessions/$livekitSessionId': {
        'serviceSessionId': serviceSessionId,
        'livekitRoomId': group.groupId,
        'groupId': group.groupId,
        'userId': identity.userId,
        'deviceId': identity.deviceId,
        'participantIdentity': token.participantIdentity,
        'participantName': token.participantName,
        'connectionState': 'connecting',
        'connectedAt': null,
        'disconnectedAt': null,
        'lastStateChangedAt': now,
      },
      'memberAvailability/${group.groupId}/${identity.userId}': {
        'activeDeviceId': identity.deviceId,
        'activeServiceSessionId': serviceSessionId,
        'activeLivekitSessionId': livekitSessionId,
        'desiredState': 'online',
        'effectiveState': 'connecting',
        'serviceState': 'starting',
        'livekitConnectionState': 'connecting',
        'canReceiveLiveAudio': false,
        'lastHeartbeatAt': now,
        'staleAfterAt': now + 30,
        'updatedAt': now,
      },
    });

    return session;
  }

  Future<void> markLive(OnlineSession session) async {
    final now = _nowSeconds();
    await _scheduleAwayOnDisconnect(session);
    await _database.ref().update({
      'appServiceSessions/${session.serviceSessionId}/serviceState': 'running',
      'appServiceSessions/${session.serviceSessionId}/lastHeartbeatAt': now,
      'livekitSessions/${session.livekitSessionId}/connectionState':
          'connected',
      'livekitSessions/${session.livekitSessionId}/connectedAt': now,
      'livekitSessions/${session.livekitSessionId}/lastStateChangedAt': now,
      'memberAvailability/${session.groupId}/${session.userId}/effectiveState':
          'live',
      'memberAvailability/${session.groupId}/${session.userId}/serviceState':
          'running',
      'memberAvailability/${session.groupId}/${session.userId}/livekitConnectionState':
          'connected',
      'memberAvailability/${session.groupId}/${session.userId}/canReceiveLiveAudio':
          true,
      'memberAvailability/${session.groupId}/${session.userId}/lastHeartbeatAt':
          now,
      'memberAvailability/${session.groupId}/${session.userId}/staleAfterAt':
          now + 30,
      'memberAvailability/${session.groupId}/${session.userId}/updatedAt': now,
    });
  }

  Future<void> heartbeat(
    OnlineSession session, {
    bool isTalking = false,
  }) async {
    final now = _nowSeconds();
    await _scheduleAwayOnDisconnect(session);
    await _database.ref().update({
      'appServiceSessions/${session.serviceSessionId}/lastHeartbeatAt': now,
      'memberAvailability/${session.groupId}/${session.userId}/desiredState':
          'online',
      'memberAvailability/${session.groupId}/${session.userId}/effectiveState':
          isTalking ? 'talking' : 'live',
      'memberAvailability/${session.groupId}/${session.userId}/serviceState':
          'running',
      'memberAvailability/${session.groupId}/${session.userId}/livekitConnectionState':
          'connected',
      'memberAvailability/${session.groupId}/${session.userId}/canReceiveLiveAudio':
          true,
      'memberAvailability/${session.groupId}/${session.userId}/lastHeartbeatAt':
          now,
      'memberAvailability/${session.groupId}/${session.userId}/staleAfterAt':
          now + 30,
      'memberAvailability/${session.groupId}/${session.userId}/updatedAt': now,
    });
  }

  Future<void> goAway(OnlineSession session) async {
    final now = _nowSeconds();
    final availabilityRef = _database.ref(
      'memberAvailability/${session.groupId}/${session.userId}',
    );
    await availabilityRef.onDisconnect().cancel();

    await _database.ref().update({
      'appServiceSessions/${session.serviceSessionId}/serviceState': 'stopped',
      'appServiceSessions/${session.serviceSessionId}/stopReason': 'user_away',
      'appServiceSessions/${session.serviceSessionId}/stoppedAt': now,
      'appServiceSessions/${session.serviceSessionId}/lastHeartbeatAt': now,
      'livekitSessions/${session.livekitSessionId}/connectionState':
          'disconnected',
      'livekitSessions/${session.livekitSessionId}/disconnectedAt': now,
      'livekitSessions/${session.livekitSessionId}/lastStateChangedAt': now,
      'memberAvailability/${session.groupId}/${session.userId}': {
        'activeDeviceId': null,
        'activeServiceSessionId': null,
        'activeLivekitSessionId': null,
        'desiredState': 'away',
        'effectiveState': 'away',
        'serviceState': 'stopped',
        'livekitConnectionState': 'disconnected',
        'canReceiveLiveAudio': false,
        'lastHeartbeatAt': now,
        'staleAfterAt': now,
        'updatedAt': now,
      },
    });
  }

  Future<void> _scheduleAwayOnDisconnect(OnlineSession session) async {
    final availabilityRef = _database.ref(
      'memberAvailability/${session.groupId}/${session.userId}',
    );
    await availabilityRef.onDisconnect().set({
      'activeDeviceId': null,
      'activeServiceSessionId': null,
      'activeLivekitSessionId': null,
      'desiredState': MemberAvailability.away.desiredState,
      'effectiveState': MemberAvailability.away.effectiveState,
      'serviceState': 'stopped',
      'livekitConnectionState': 'disconnected',
      'canReceiveLiveAudio': false,
      'lastHeartbeatAt': 0,
      'staleAfterAt': 0,
      'updatedAt': _nowSeconds(),
    });
  }

  Future<LiveKitTokenResponse> _requestLiveKitToken({
    required String groupId,
    required String deviceId,
    required String serviceSessionId,
    required String livekitSessionId,
  }) async {
    final response = await _apiClient.postJson('/v1/livekit/token', {
      'groupId': groupId,
      'deviceId': deviceId,
      'serviceSessionId': serviceSessionId,
      'livekitSessionId': livekitSessionId,
    });
    return LiveKitTokenResponse.fromJson(response);
  }

  Future<void> _requestOnlinePermissions() async {
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      throw StateError(
        'Microphone permission is required before going online.',
      );
    }
  }

  int _nowSeconds() {
    return DateTime.now().millisecondsSinceEpoch ~/ 1000;
  }
}
