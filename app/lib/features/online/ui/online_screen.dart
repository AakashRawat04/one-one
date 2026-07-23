import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../../core/firebase/app_database.dart';
import '../../groups/models/group_summary.dart';
import '../../identity/models/identity_session.dart';
import '../../talk/data/talk_repository.dart';
import '../../talk/models/talk_session.dart';
import '../data/online_repository.dart';
import '../livekit_status.dart';
import '../models/online_session.dart';
import '../presence_config.dart';

class OnlineScreen extends StatefulWidget {
  const OnlineScreen({
    super.key,
    required this.identity,
    required this.group,
    this.onlineRepository,
    this.talkRepository,
  });

  final IdentitySession identity;
  final GroupSummary group;
  final OnlineRepository? onlineRepository;
  final TalkRepository? talkRepository;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  late final OnlineRepository _onlineRepository =
      widget.onlineRepository ?? OnlineRepository();
  late final TalkRepository _talkRepository =
      widget.talkRepository ?? TalkRepository();
  OnlineSession? _session;
  TalkSession? _talkSession;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  Timer? _heartbeatTimer;
  Timer? _inactivityTimer;
  Timer? _usagePersistTimer;
  DateTime? _lastVoiceActivityAt;
  int _todayOnlineSeconds = 0;
  String? _todayUsageDateKey;
  String _state = 'away';
  String? _message;
  bool _busy = false;
  bool _talkBusy = false;

  String get _todayDateKey {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
    _inactivityTimer?.cancel();
    _usagePersistTimer?.cancel();
    if (_todayOnlineSeconds > 0 && _session != null) {
      unawaited(_persistDailyUsage());
    }
    final activeTalk = _talkSession;
    if (activeTalk != null) {
      unawaited(_talkRepository.stopTalk(activeTalk, reason: 'screen_closed'));
    }
    unawaited(_disconnectLiveKit());
    super.dispose();
  }

  Future<void> _goOnline() async {
    setState(() {
      _busy = true;
      _state = 'connecting';
      _message = null;
    });

    // Check daily usage cap.
    final dateKey = _todayDateKey;
    if (_todayUsageDateKey != dateKey) {
      _todayUsageDateKey = dateKey;
      _todayOnlineSeconds = 0;
    }
    final loadedSeconds = await _loadDailyUsage();
    if (loadedSeconds > _todayOnlineSeconds) {
      _todayOnlineSeconds = loadedSeconds;
    }
    if (_todayOnlineSeconds >= PresenceConfig.dailyUsageCap.inSeconds) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _state = 'away';
        _message = 'Daily usage limit reached (${PresenceConfig.dailyUsageCap.inMinutes} min). '
            'You can go online again tomorrow.';
      });
      return;
    }

    OnlineSession? createdSession;
    try {
      createdSession = await _onlineRepository.goOnline(
        identity: widget.identity,
        group: widget.group,
      );
      await _connectLiveKit(createdSession);
      await _onlineRepository.markLive(createdSession);
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        final activeSession = _session;
        if (activeSession != null) {
          unawaited(_onlineRepository.heartbeat(activeSession));
        }
      });

      setState(() {
        _session = createdSession;
        _state = 'live';
        _message = LiveKitStatus.live;
      });
      _scheduleInactivityCheck();
      _startUsageTracking();
    } catch (error) {
      await _disconnectLiveKit();
      if (createdSession != null) {
        try {
          await _onlineRepository.goAway(createdSession);
        } catch (_) {
          // Best-effort cleanup after a failed connect.
        }
      }
      if (!mounted) return;
      setState(() {
        _state = 'away';
        _message = LiveKitStatus.sanitizeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _goAway() async {
    final session = _session;
    if (session == null) {
      setState(() => _state = 'away');
      return;
    }

    setState(() {
      _busy = true;
      _message = null;
    });

    try {
      final activeTalk = _talkSession;
      if (activeTalk != null) {
        await _talkRepository.stopTalk(activeTalk, reason: 'going_away');
      }
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      _lastVoiceActivityAt = null;
      _usagePersistTimer?.cancel();
      _usagePersistTimer = null;
      if (_todayOnlineSeconds > 0) {
        unawaited(_persistDailyUsage());
      }
      await _disconnectLiveKit();
      await _onlineRepository.goAway(session);
      setState(() {
        _session = null;
        _talkSession = null;
        _state = 'away';
        _message = LiveKitStatus.away;
      });
    } catch (error) {
      setState(() => _message = LiveKitStatus.sanitizeError(error));
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _startTalking() async {
    final session = _session;
    if (session == null || _talkSession != null || _talkBusy) return;

    setState(() {
      _talkBusy = true;
      _message = null;
    });

    TalkSession? startedTalk;
    try {
      startedTalk = await _talkRepository.startTalk(session);
      await _setMicrophoneEnabled(true);
      if (!mounted) return;
      setState(() {
        _talkSession = startedTalk;
        _state = 'talking';
        _message = LiveKitStatus.talking;
      });
      _recordVoiceActivity();
    } catch (error) {
      if (startedTalk != null) {
        await _talkRepository.stopTalk(startedTalk, reason: 'mic_failed');
      }
      if (!mounted) return;
      setState(() {
        _talkSession = null;
        _state = _session == null ? 'away' : 'live';
        _message = LiveKitStatus.sanitizeError(error);
      });
    } finally {
      if (mounted) {
        setState(() => _talkBusy = false);
      }
    }
  }

  Future<void> _stopTalking({String reason = 'released'}) async {
    final talkSession = _talkSession;
    if (talkSession == null) return;

    setState(() {
      _talkSession = null;
      _state = 'live';
    });
    _recordVoiceActivity();

    try {
      await _setMicrophoneEnabled(false);
      await _talkRepository.stopTalk(talkSession, reason: reason);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'Couldn’t stop talking. Try again.';
      });
    }
  }

  Future<void> _connectLiveKit(OnlineSession session) async {
    await _disconnectLiveKit();

    final room = Room(
      roomOptions: const RoomOptions(
        adaptiveStream: false,
        dynacast: false,
        defaultAudioOutputOptions: AudioOutputOptions(speakerOn: true),
      ),
    );

    _room = room;
    _attachRoomListener(room);

    setState(() {
      _state = 'connecting';
      _message = LiveKitStatus.connecting;
    });

    await room
        .connect(
          session.livekitServerUrl,
          session.livekitToken,
          connectOptions: const ConnectOptions(autoSubscribe: true),
        )
        .timeout(const Duration(seconds: 20));

    try {
      await room.setSpeakerOn(true);
    } catch (_) {
      // Non-fatal. LiveKit can still use the platform default audio route.
    }

    final localParticipant = room.localParticipant;
    if (localParticipant == null) {
      throw StateError('LiveKit connected without a local participant.');
    }

    await localParticipant
        .setMicrophoneEnabled(false)
        .timeout(const Duration(seconds: 8));
  }

  void _attachRoomListener(Room room) {
    _roomListener = room.createListener()
      ..on<RoomConnectedEvent>((_) {
        _setMessage(LiveKitStatus.connected);
      })
      ..on<RoomReconnectingEvent>((_) {
        _setStateAndMessage('reconnecting', LiveKitStatus.reconnecting);
      })
      ..on<RoomReconnectedEvent>((_) {
        _setStateAndMessage('live', LiveKitStatus.connected);
      })
      ..on<RoomDisconnectedEvent>((event) {
        _setStateAndMessage(
          'disconnected',
          LiveKitStatus.fromDisconnectReason(event.reason),
        );
      })
      ..on<ParticipantConnectedEvent>((_) {})
      ..on<TrackSubscribedEvent>((_) {})
      ..on<ActiveSpeakersChangedEvent>((event) {
        final remoteSpeakers = event.speakers.where(
          (speaker) => speaker.identity != room.localParticipant?.identity,
        );
        if (event.speakers.isNotEmpty) {
          _recordVoiceActivity();
        }
        if (remoteSpeakers.isNotEmpty) {
          _setMessage(LiveKitStatus.receivingVoice);
        }
      });
  }

  Future<void> _disconnectLiveKit() async {
    final room = _room;
    _room = null;
    _roomListener?.dispose();
    _roomListener = null;

    try {
      final localParticipant = room?.localParticipant;
      if (localParticipant != null) {
        await localParticipant.setMicrophoneEnabled(false);
      }
    } catch (_) {
      // Ignore cleanup failures.
    }

    await room?.disconnect();
  }

  Future<void> _setMicrophoneEnabled(bool enabled) async {
    final participant = _room?.localParticipant;
    if (participant == null) {
      throw StateError('LiveKit is not connected yet.');
    }

    await participant
        .setMicrophoneEnabled(enabled)
        .timeout(const Duration(seconds: 8));
  }

  void _setMessage(String message) {
    if (!mounted) return;
    setState(() => _message = message);
  }

  void _setStateAndMessage(String state, String message) {
    if (!mounted) return;
    setState(() {
      _state = state;
      _message = message;
    });
  }

  void _recordVoiceActivity() {
    if (_session == null) return;
    _lastVoiceActivityAt = DateTime.now();
    _scheduleInactivityCheck();
  }

  void _scheduleInactivityCheck() {
    _inactivityTimer?.cancel();
    if (_session == null) return;
    _inactivityTimer = Timer(PresenceConfig.inactivityTimeout, () {
      if (!mounted || _session == null) return;
      final lastActivity = _lastVoiceActivityAt;
      if (lastActivity != null &&
          DateTime.now().difference(lastActivity) <
              PresenceConfig.inactivityTimeout) {
        _scheduleInactivityCheck();
        return;
      }
      setState(() => _message = 'Room closed due to inactivity.');
      unawaited(_goAway());
    });
  }

  Future<int> _loadDailyUsage() async {
    final session = _session;
    if (session == null) return 0;
    try {
      final snapshot = await AppDatabase.instance()
          .ref('dailyUsage/${session.groupId}/${session.userId}/$_todayDateKey')
          .get();
      if (snapshot.exists && snapshot.value is Map<Object?, Object?>) {
        final data = snapshot.value! as Map<Object?, Object?>;
        return (data['onlineSeconds'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {}
    return 0;
  }

  Future<void> _persistDailyUsage() async {
    final session = _session;
    if (session == null) return;
    try {
      await AppDatabase.instance()
          .ref('dailyUsage/${session.groupId}/${session.userId}/$_todayDateKey')
          .update({
            'onlineSeconds': _todayOnlineSeconds,
            'updatedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          });
    } catch (_) {}
  }

  void _startUsageTracking() {
    final session = _session;
    if (session == null) return;
    _usagePersistTimer?.cancel();
    unawaited(_persistDailyUsage());
    _usagePersistTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_session == null) {
        _usagePersistTimer?.cancel();
        _usagePersistTimer = null;
        return;
      }
      _todayOnlineSeconds += 30;
      unawaited(_persistDailyUsage());
      if (_todayOnlineSeconds >= PresenceConfig.dailyUsageCap.inSeconds) {
        if (mounted) {
          setState(() => _message = 'Daily usage limit reached.');
        }
        unawaited(_goAway());
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.group.name),
        backgroundColor: colors.inversePrimary,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                _state.toUpperCase(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 12),
              Text('Group: ${widget.group.groupId}'),
              const SizedBox(height: 24),
              _TalkButton(
                enabled: _session != null && !_busy,
                active: _talkSession != null,
                busy: _talkBusy,
                onStart: _startTalking,
                onStop: () => _stopTalking(),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _busy || _session != null ? null : _goOnline,
                icon: const Icon(Icons.radio_button_checked),
                label: const Text('Go online'),
              ),
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _busy || _session == null ? null : _goAway,
                icon: const Icon(Icons.radio_button_unchecked),
                label: const Text('Go away'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 24),
                Text(_message!),
              ],
              const Spacer(),
              Text(
                'Hold-to-talk is available after you are live.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TalkButton extends StatelessWidget {
  const _TalkButton({
    required this.enabled,
    required this.active,
    required this.busy,
    required this.onStart,
    required this.onStop,
  });

  final bool enabled;
  final bool active;
  final bool busy;
  final Future<void> Function() onStart;
  final Future<void> Function() onStop;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final backgroundColor = active
        ? colors.error
        : enabled
        ? colors.primary
        : colors.surfaceContainerHighest;
    final foregroundColor = active || enabled
        ? colors.onPrimary
        : colors.onSurfaceVariant;

    return GestureDetector(
      onTapDown: enabled && !busy ? (_) => onStart() : null,
      onTapUp: enabled ? (_) => onStop() : null,
      onTapCancel: enabled ? () => onStop() : null,
      child: Container(
        height: 136,
        decoration: BoxDecoration(
          color: backgroundColor,
          borderRadius: BorderRadius.circular(8),
        ),
        alignment: Alignment.center,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              active ? Icons.mic : Icons.mic_none,
              color: foregroundColor,
              size: 42,
            ),
            const SizedBox(height: 8),
            Text(
              busy
                  ? 'WAIT'
                  : active
                  ? 'TALKING'
                  : 'HOLD TO TALK',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: foregroundColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
