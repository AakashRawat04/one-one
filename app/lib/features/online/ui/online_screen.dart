import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../../../phase1_spike/spike_keys.dart';
import '../../groups/models/group_summary.dart';
import '../../identity/models/identity_session.dart';
import '../../notifications/data/notification_repository.dart';
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
    this.notificationRepository,
    this.talkRepository,
  });

  final IdentitySession identity;
  final GroupSummary group;
  final OnlineRepository? onlineRepository;
  final NotificationRepository? notificationRepository;
  final TalkRepository? talkRepository;

  @override
  State<OnlineScreen> createState() => _OnlineScreenState();
}

class _OnlineScreenState extends State<OnlineScreen> {
  late final OnlineRepository _onlineRepository =
      widget.onlineRepository ?? OnlineRepository();
  late final NotificationRepository _notificationRepository =
      widget.notificationRepository ?? NotificationRepository();
  late final TalkRepository _talkRepository =
      widget.talkRepository ?? TalkRepository();
  OnlineSession? _session;
  TalkSession? _talkSession;
  Timer? _heartbeatTimer;
  String _state = 'away';
  String? _message;
  bool _busy = false;
  bool _talkBusy = false;
  bool _friendLiveSent = false;

  @override
  void initState() {
    super.initState();
    FlutterForegroundTask.addTaskDataCallback(_onTaskData);
  }

  @override
  void dispose() {
    FlutterForegroundTask.removeTaskDataCallback(_onTaskData);
    _heartbeatTimer?.cancel();
    final activeTalk = _talkSession;
    if (activeTalk != null) {
      unawaited(_talkRepository.stopTalk(activeTalk, reason: 'screen_closed'));
    }
    super.dispose();
  }

  Future<void> _goOnline() async {
    setState(() {
      _busy = true;
      _state = 'connecting';
      _message = null;
    });

    try {
      final session = await _onlineRepository.goOnline(
        identity: widget.identity,
        group: widget.group,
      );
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        final activeSession = _session;
        if (activeSession != null) {
          _onlineRepository.heartbeat(activeSession);
        }
      });

      setState(() {
        _session = session;
        _message = 'Foreground service requested';
      });
    } catch (error) {
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
      await _onlineRepository.goAway(session);
      setState(() {
        _session = null;
        _talkSession = null;
        _state = 'away';
        _friendLiveSent = false;
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

    try {
      final talkSession = await _talkRepository.startTalk(session);
      if (!mounted) return;
      setState(() {
        _talkSession = talkSession;
        _state = 'talking';
        _message = 'Talking';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
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
      await _talkRepository.stopTalk(talkSession, reason: reason);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'Talk stop failed: $error';
      });
    }
  }

  void _onTaskData(Object data) {
    if (data is! Map) return;

    final status = data[taskStatusKey]?.toString();
    final message = data[taskMessageKey]?.toString();
    if (status == null) return;

    setState(() {
      _state = status;
      if (message != null && message.isNotEmpty) {
        _message = message;
      }
    });

    final session = _session;
    if (session != null && status == 'connected' && !_friendLiveSent) {
      _friendLiveSent = true;
      _markLiveAndNotify(session);
    }
  }

  Future<void> _markLiveAndNotify(OnlineSession session) async {
    try {
      await _onlineRepository.markLive(session);
      final result = await _notificationRepository.sendFriendLive(session);
      if (!mounted) return;
      setState(() {
        _message =
            'Live notification sent to ${result.targetDevices} device(s).';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = 'Live, but notification failed: $error';
      });
    }
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
