import 'dart:async';

import 'package:flutter/material.dart';
import 'package:livekit_client/livekit_client.dart';

import '../../groups/models/group_summary.dart';
import '../../identity/models/identity_session.dart';
import '../../talk/data/talk_repository.dart';
import '../../talk/models/talk_session.dart';
import '../data/online_repository.dart';
import '../models/online_session.dart';

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
  String _state = 'away';
  String? _message;
  bool _busy = false;
  bool _talkBusy = false;

  @override
  void dispose() {
    _heartbeatTimer?.cancel();
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
        _message = 'Live';
      });
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
        _message = error.toString();
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
      await _disconnectLiveKit();
      await _onlineRepository.goAway(session);
      setState(() {
        _session = null;
        _talkSession = null;
        _state = 'away';
        _message = 'Away';
      });
    } catch (error) {
      setState(() => _message = error.toString());
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
        _message = 'Talking';
      });
    } catch (error) {
      if (startedTalk != null) {
        await _talkRepository.stopTalk(startedTalk, reason: 'mic_failed');
      }
      if (!mounted) return;
      setState(() {
        _talkSession = null;
        _state = _session == null ? 'away' : 'live';
        _message = error.toString();
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

    try {
      await _setMicrophoneEnabled(false);
      await _talkRepository.stopTalk(talkSession, reason: reason);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'Talk stop failed: $error';
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
      _message = 'Connecting to LiveKit';
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
        _setMessage('LiveKit connected');
      })
      ..on<RoomReconnectingEvent>((_) {
        _setStateAndMessage('reconnecting', 'LiveKit reconnecting');
      })
      ..on<RoomReconnectedEvent>((_) {
        _setStateAndMessage('live', 'LiveKit reconnected');
      })
      ..on<RoomDisconnectedEvent>((event) {
        _setStateAndMessage(
          'disconnected',
          'LiveKit disconnected: ${event.reason}',
        );
      })
      ..on<ParticipantConnectedEvent>((event) {
        _setMessage('${event.participant.identity} joined');
      })
      ..on<TrackSubscribedEvent>((event) {
        final isAudio = event.track is RemoteAudioTrack;
        _setMessage(
          isAudio
              ? 'Audio subscribed from ${event.participant.identity}'
              : 'Track subscribed from ${event.participant.identity}',
        );
      })
      ..on<ActiveSpeakersChangedEvent>((event) {
        final remoteSpeakers = event.speakers.where(
          (speaker) => speaker.identity != room.localParticipant?.identity,
        );
        if (remoteSpeakers.isNotEmpty) {
          _setMessage('Receiving voice');
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
