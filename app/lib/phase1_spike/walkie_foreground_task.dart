import 'dart:async';

import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:livekit_client/livekit_client.dart';

import 'spike_keys.dart';

@pragma('vm:entry-point')
void walkieForegroundServiceCallback() {
  FlutterForegroundTask.setTaskHandler(WalkieForegroundTaskHandler());
}

class WalkieForegroundTaskHandler extends TaskHandler {
  Room? _room;
  EventsListener<RoomEvent>? _listener;
  String _status = 'starting';
  int _heartbeatCount = 0;

  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    _sendStatus('starting', 'Foreground service started by ${starter.name}.');
    await _connectFromStoredConfig();
  }

  @override
  void onRepeatEvent(DateTime timestamp) {
    _heartbeatCount++;
    _sendData({
      taskEventTypeKey: 'heartbeat',
      taskStatusKey: _status,
      taskHeartbeatCountKey: _heartbeatCount,
      taskTimestampKey: timestamp.toIso8601String(),
    });

    FlutterForegroundTask.updateService(
      notificationTitle: 'One One is online',
      notificationText: 'Status: $_status | heartbeat $_heartbeatCount',
    );
  }

  @override
  Future<void> onDestroy(DateTime timestamp, bool isTimeout) async {
    _sendStatus(
      'stopping',
      'Foreground service stopping${isTimeout ? ' after timeout' : ''}.',
    );
    await _disconnectRoom();
  }

  @override
  void onReceiveData(Object data) {
    if (data is! Map) return;

    final command = data[taskCommandKey];
    if (command == taskCommandDisconnect) {
      unawaited(_disconnectAndStop());
    } else if (command == taskCommandEnableMic) {
      unawaited(_setMicrophoneEnabled(true));
    } else if (command == taskCommandDisableMic) {
      unawaited(_setMicrophoneEnabled(false));
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      unawaited(_disconnectAndStop());
    }
  }

  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
  }

  @override
  void onNotificationDismissed() {
    _sendStatus('notification_dismissed', 'Foreground notification dismissed.');
  }

  Future<void> _connectFromStoredConfig() async {
    final String? url = await FlutterForegroundTask.getData<String>(
      key: liveKitUrlKey,
    );
    final String? token = await FlutterForegroundTask.getData<String>(
      key: liveKitTokenKey,
    );

    if (url == null || url.trim().isEmpty || token == null || token.isEmpty) {
      _status = 'missing_config';
      _sendStatus(
        _status,
        'Missing LiveKit URL or token. Start the service from the app screen.',
      );
      return;
    }

    try {
      _status = 'connecting';
      _sendStatus('connecting', 'Connecting to LiveKit from service isolate.');

      final room = Room(
        roomOptions: const RoomOptions(adaptiveStream: false, dynacast: false),
      );
      _room = room;
      _attachRoomListener(room);

      await room.connect(
        url.trim(),
        token.trim(),
        connectOptions: const ConnectOptions(autoSubscribe: true),
      );

      await room.localParticipant?.setMicrophoneEnabled(false);
      _status = 'connected';
      _sendStatus(
        'connected',
        'LiveKit connected. Mic is muted; remote audio auto-subscribe is on.',
      );
    } catch (error, stackTrace) {
      _status = 'failed';
      _sendStatus('failed', '$error');
      _sendData({
        taskEventTypeKey: 'error',
        taskStatusKey: _status,
        taskMessageKey: stackTrace.toString(),
        taskTimestampKey: DateTime.now().toIso8601String(),
      });
      await _disconnectRoom();
    }
  }

  void _attachRoomListener(Room room) {
    _listener = room.createListener()
      ..on<RoomConnectedEvent>((event) {
        _status = 'connected';
        _sendStatus('connected', 'Room connected. Metadata: ${event.metadata}');
      })
      ..on<RoomReconnectingEvent>((_) {
        _status = 'reconnecting';
        _sendStatus('reconnecting', 'LiveKit is reconnecting.');
      })
      ..on<RoomResumingEvent>((_) {
        _status = 'resuming';
        _sendStatus('resuming', 'LiveKit is resuming the signal connection.');
      })
      ..on<RoomReconnectedEvent>((_) {
        _status = 'connected';
        _sendStatus('connected', 'LiveKit reconnected.');
      })
      ..on<RoomDisconnectedEvent>((event) {
        _status = 'disconnected';
        _sendStatus('disconnected', 'Disconnected: ${event.reason}');
      })
      ..on<ParticipantConnectedEvent>((event) {
        _sendStatus('participant_joined', event.participant.identity);
      })
      ..on<ParticipantDisconnectedEvent>((event) {
        _sendStatus('participant_left', event.participant.identity);
      })
      ..on<TrackSubscribedEvent>((event) {
        final isAudio = event.track is RemoteAudioTrack;
        _sendStatus(
          isAudio ? 'audio_subscribed' : 'track_subscribed',
          'Subscribed to ${isAudio ? 'audio' : 'track'} from '
          '${event.participant.identity}.',
        );
      })
      ..on<TrackUnsubscribedEvent>((event) {
        _sendStatus(
          'track_unsubscribed',
          'Unsubscribed from track by ${event.participant.identity}.',
        );
      })
      ..on<TrackSubscriptionExceptionEvent>((event) {
        _sendStatus(
          'subscription_failed',
          'Track subscription failed: ${event.reason}.',
        );
      });
  }

  Future<void> _disconnectAndStop() async {
    _sendStatus('stopping', 'Disconnect command received.');
    await _disconnectRoom();
    await FlutterForegroundTask.stopService();
  }

  Future<void> _setMicrophoneEnabled(bool enabled) async {
    final room = _room;
    final localParticipant = room?.localParticipant;

    if (room == null || localParticipant == null) {
      _sendStatus('mic_failed', 'Cannot change mic before LiveKit connects.');
      return;
    }

    try {
      await localParticipant.setMicrophoneEnabled(enabled);
      _sendStatus(
        enabled ? 'talking' : 'live',
        enabled ? 'Microphone enabled.' : 'Microphone muted.',
      );

      FlutterForegroundTask.updateService(
        notificationTitle: 'One One is online',
        notificationText: enabled ? 'Talking' : 'Live and listening',
      );
    } catch (error) {
      _sendStatus('mic_failed', 'Microphone change failed: $error');
    }
  }

  Future<void> _disconnectRoom() async {
    final room = _room;
    _room = null;
    _listener?.dispose();
    _listener = null;
    await room?.disconnect();
  }

  void _sendStatus(String status, String message) {
    _status = status;
    _sendData({
      taskEventTypeKey: 'status',
      taskStatusKey: status,
      taskMessageKey: message,
      taskTimestampKey: DateTime.now().toIso8601String(),
    });
  }

  void _sendData(Map<String, Object?> data) {
    FlutterForegroundTask.sendDataToMain(data);
  }
}
