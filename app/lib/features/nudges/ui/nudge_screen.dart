import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:record/record.dart';

import '../../../core/network/api_client.dart';
import '../../groups/models/group_member_summary.dart';
import '../../groups/models/group_summary.dart';
import '../../identity/ui/profile_avatar.dart';
import '../data/nudge_repository.dart';

Future<void> showNudgeBottomSheet(
  BuildContext context, {
  required GroupSummary group,
  required String currentUserId,
  required List<GroupMemberSummary> members,
  required Color accent,
}) async {
  final openVoiceComposer = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
    ),
    builder: (_) => _QuickNudgeSheet(
      group: group,
      currentUserId: currentUserId,
      members: members,
      accent: accent,
    ),
  );
  if (openVoiceComposer != true || !context.mounted) return;
  await Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => NudgeScreen(
        group: group,
        currentUserId: currentUserId,
        members: members,
        accent: accent,
      ),
    ),
  );
}

class _QuickNudgeSheet extends StatefulWidget {
  const _QuickNudgeSheet({
    required this.group,
    required this.currentUserId,
    required this.members,
    required this.accent,
  });

  final GroupSummary group;
  final String currentUserId;
  final List<GroupMemberSummary> members;
  final Color accent;

  @override
  State<_QuickNudgeSheet> createState() => _QuickNudgeSheetState();
}

class _QuickNudgeSheetState extends State<_QuickNudgeSheet> {
  final NudgeRepository _repository = NudgeRepository();
  NudgeTarget _target = const NudgeTarget.allFriends();
  bool _busy = false;
  String? _message;
  bool _messageIsError = false;

  List<GroupMemberSummary> get _friends => widget.members
      .where(
        (member) =>
            member.userId != widget.currentUserId &&
            member.memberState == 'active',
      )
      .toList(growable: false);

  Future<void> _sendRing(int seconds) async {
    await _send(
      () => _repository.sendRing(
        groupId: widget.group.groupId,
        target: _target,
        durationSeconds: seconds,
      ),
      '$seconds second nudge sent',
    );
  }

  Future<void> _sendPush() async {
    await _send(
      () => _repository.sendPush(
        groupId: widget.group.groupId,
        target: _target,
      ),
      'Notification nudge sent',
    );
  }

  Future<void> _send(
    Future<Object?> Function() action,
    String successMessage,
  ) async {
    if (_busy || _friends.isEmpty) return;
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      await action();
      if (mounted) {
        setState(() {
          _message = successMessage;
          _messageIsError = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      final message = error is NudgeDeliveryException
          ? error.message
          : error is ApiException && error.code == 'nudge_rate_limited'
          ? error.message
          : 'Couldn’t send the nudge. Check your connection.';
      setState(() {
        _message = message;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final actionEnabled = !_busy && _friends.isNotEmpty;
    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.72,
      ),
      decoration: BoxDecoration(
        color: const Color(0xff141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(20.w, 10.h, 20.w, 22.h),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38.w,
                height: 4.h,
                decoration: BoxDecoration(
                  color: Colors.white24,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            SizedBox(height: 18.h),
            Row(
              children: [
                Container(
                  width: 44.w,
                  height: 44.w,
                  decoration: BoxDecoration(
                    color: widget.accent.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(14.r),
                  ),
                  child: Icon(
                    Icons.notifications_active_rounded,
                    color: widget.accent,
                    size: 22.sp,
                  ),
                ),
                SizedBox(width: 12.w),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Send a nudge',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 19.sp,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 2.h),
                      Text(
                        widget.group.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 12.sp,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _busy ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: Colors.white54,
                  tooltip: 'Close',
                ),
              ],
            ),
            SizedBox(height: 20.h),
            Text(
              'SEND TO',
              style: TextStyle(
                color: Colors.white38,
                fontSize: 10.sp,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.3,
              ),
            ),
            SizedBox(height: 10.h),
            SizedBox(
              height: 78.h,
              child: ListView(
                scrollDirection: Axis.horizontal,
                children: [
                  _NudgeRecipient(
                    label: 'Everyone',
                    selected: _target.targetScope == 'all_friends',
                    accent: widget.accent,
                    onTap: _busy
                        ? null
                        : () => setState(
                            () => _target = const NudgeTarget.allFriends(),
                          ),
                    avatar: Icon(
                      Icons.group_rounded,
                      color: Colors.white,
                      size: 24.sp,
                    ),
                  ),
                  for (final friend in _friends) ...[
                    SizedBox(width: 12.w),
                    _NudgeRecipient(
                      label: friend.displayName,
                      selected: _target.targetUserId == friend.userId,
                      accent: widget.accent,
                      onTap: _busy
                          ? null
                          : () => setState(
                              () => _target =
                                  NudgeTarget.singleFriend(friend.userId),
                            ),
                      avatar: ProfileAvatar(
                        profilePhotoUrl: friend.profilePhotoUrl,
                        profilePhotoBase64: friend.profilePhotoBase64,
                        radius: 24.r,
                        fallback: Text(
                          friend.displayName.trim().isEmpty
                              ? '?'
                              : String.fromCharCode(
                                  friend.displayName.trim().runes.first,
                                ).toUpperCase(),
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 17.sp,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            SizedBox(height: 18.h),
            _QuickRingCard(
              accent: widget.accent,
              enabled: actionEnabled,
              busy: _busy,
              onSelected: _sendRing,
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: _NudgeModeButton(
                    icon: Icons.notifications_none_rounded,
                    label: 'Push',
                    detail: 'Quick alert',
                    enabled: actionEnabled,
                    onTap: _sendPush,
                  ),
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: _NudgeModeButton(
                    icon: Icons.mic_none_rounded,
                    label: 'Voice',
                    detail: 'Up to 6 sec',
                    enabled: actionEnabled,
                    onTap: () => Navigator.of(context).pop(true),
                  ),
                ),
              ],
            ),
            if (_friends.isEmpty) ...[
              SizedBox(height: 12.h),
              const _NudgeStatus(
                message: 'Invite a friend before sending a nudge.',
                isError: true,
              ),
            ] else if (_message != null) ...[
              SizedBox(height: 12.h),
              _NudgeStatus(
                message: _message!,
                isError: _messageIsError,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NudgeRecipient extends StatelessWidget {
  const _NudgeRecipient({
    required this.label,
    required this.selected,
    required this.accent,
    required this.avatar,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final Color accent;
  final Widget avatar;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      label: 'Send to $label',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18.r),
        child: SizedBox(
          width: 62.w,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.all(3.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff242424),
                  border: Border.all(
                    color: selected ? accent : Colors.white12,
                    width: selected ? 2 : 1,
                  ),
                ),
                child: ClipOval(
                  child: SizedBox(width: 48.r, height: 48.r, child: avatar),
                ),
              ),
              SizedBox(height: 5.h),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: selected ? Colors.white : Colors.white54,
                  fontSize: 10.sp,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QuickRingCard extends StatelessWidget {
  const _QuickRingCard({
    required this.accent,
    required this.enabled,
    required this.busy,
    required this.onSelected,
  });

  final Color accent;
  final bool enabled;
  final bool busy;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(14.r),
      decoration: BoxDecoration(
        color: const Color(0xff1b1b1b),
        borderRadius: BorderRadius.circular(20.r),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.vibration_rounded, color: accent, size: 19.sp),
              SizedBox(width: 8.w),
              Text(
                'Quick ring',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 14.sp,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (busy)
                SizedBox(
                  width: 16.r,
                  height: 16.r,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: accent,
                  ),
                )
              else
                Text(
                  'Choose duration',
                  style: TextStyle(color: Colors.white38, fontSize: 10.sp),
                ),
            ],
          ),
          SizedBox(height: 12.h),
          Row(
            children: [
              for (final seconds in const [3, 5, 10]) ...[
                if (seconds != 3) SizedBox(width: 8.w),
                Expanded(
                  child: Material(
                    color: enabled
                        ? accent.withValues(alpha: 0.14)
                        : Colors.white.withValues(alpha: 0.04),
                    borderRadius: BorderRadius.circular(14.r),
                    child: InkWell(
                      onTap: enabled ? () => onSelected(seconds) : null,
                      borderRadius: BorderRadius.circular(14.r),
                      child: Container(
                        height: 50.h,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14.r),
                          border: Border.all(
                            color: enabled
                                ? accent.withValues(alpha: 0.34)
                                : Colors.white10,
                          ),
                        ),
                        child: Text.rich(
                          TextSpan(
                            text: '$seconds',
                            style: TextStyle(
                              color: enabled ? Colors.white : Colors.white24,
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                            children: [
                              TextSpan(
                                text: ' sec',
                                style: TextStyle(
                                  color: enabled
                                      ? Colors.white54
                                      : Colors.white24,
                                  fontSize: 10.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _NudgeModeButton extends StatelessWidget {
  const _NudgeModeButton({
    required this.icon,
    required this.label,
    required this.detail,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String detail;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: const Color(0xff1b1b1b),
      borderRadius: BorderRadius.circular(18.r),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(18.r),
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 14.w, vertical: 13.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18.r),
            border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
          ),
          child: Row(
            children: [
              Icon(
                icon,
                color: enabled ? Colors.white : Colors.white24,
                size: 21.sp,
              ),
              SizedBox(width: 9.w),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        color: enabled ? Colors.white : Colors.white24,
                        fontSize: 13.sp,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      detail,
                      style: TextStyle(
                        color: enabled ? Colors.white38 : Colors.white24,
                        fontSize: 9.sp,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: enabled ? Colors.white30 : Colors.white12,
                size: 18.sp,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NudgeStatus extends StatelessWidget {
  const _NudgeStatus({required this.message, required this.isError});

  final String message;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final color = isError ? const Color(0xffff6b6f) : const Color(0xff9bdc28);
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12.w, vertical: 10.h),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(14.r),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Row(
        children: [
          Icon(
            isError ? Icons.error_outline_rounded : Icons.check_circle_outline,
            color: color,
            size: 17.sp,
          ),
          SizedBox(width: 8.w),
          Expanded(
            child: Text(
              message,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 11.sp,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class NudgeScreen extends StatefulWidget {
  const NudgeScreen({
    super.key,
    required this.group,
    required this.currentUserId,
    required this.members,
    required this.accent,
  });

  final GroupSummary group;
  final String currentUserId;
  final List<GroupMemberSummary> members;
  final Color accent;

  @override
  State<NudgeScreen> createState() => _NudgeScreenState();
}

class _NudgeScreenState extends State<NudgeScreen> {
  static const _maxVoiceDuration = Duration(seconds: 6);

  final NudgeRepository _repository = NudgeRepository();
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _recordingWatch = Stopwatch();
  NudgeTarget _target = const NudgeTarget.allFriends();
  Timer? _recordingTimer;
  bool _recording = false;
  bool _startingRecording = false;
  bool _finishingRecording = false;
  bool _pointerHeld = false;
  bool _sendAfterPointerEnd = true;
  bool _busy = false;
  Duration _elapsed = Duration.zero;
  String? _message;

  List<GroupMemberSummary> get _friends => widget.members
      .where(
        (member) =>
            member.userId != widget.currentUserId &&
            member.memberState == 'active',
      )
      .toList(growable: false);

  bool get _canSend =>
      _friends.isNotEmpty && !_busy && !_startingRecording && !_finishingRecording;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    if (_recording) unawaited(_recorder.stop());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  Future<void> _sendPush() async {
    await _runSend(
      () => _repository.sendPush(
        groupId: widget.group.groupId,
        target: _target,
      ),
      'Notification nudge sent',
    );
  }

  Future<void> _sendRing(int durationSeconds) async {
    await _runSend(
      () => _repository.sendRing(
        groupId: widget.group.groupId,
        target: _target,
        durationSeconds: durationSeconds,
      ),
      '$durationSeconds second ring sent',
    );
  }

  Future<void> _runSend(
    Future<Object?> Function() action,
    String successMessage,
  ) async {
    if (!_canSend) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
      if (mounted) setState(() => _message = successMessage);
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _beginRecording() async {
    if (!_canSend || _recording || _startingRecording) return;
    _startingRecording = true;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) setState(() => _message = 'Microphone permission is required.');
        return;
      }
      final file = File(
        '${Directory.systemTemp.path}/one_one_voice_${DateTime.now().microsecondsSinceEpoch}.m4a',
      );
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 64000,
          sampleRate: 44100,
          numChannels: 1,
          autoGain: true,
          echoCancel: true,
          noiseSuppress: true,
        ),
        path: file.path,
      );
      if (!mounted) {
        await _recorder.stop();
        return;
      }
      _recordingWatch
        ..reset()
        ..start();
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted || !_recording) return;
        final elapsed = _recordingWatch.elapsed;
        setState(() => _elapsed = elapsed);
        if (elapsed >= _maxVoiceDuration) {
          unawaited(_finishRecording(send: true));
        }
      });
      if (mounted) {
        setState(() {
          _recording = true;
          _elapsed = Duration.zero;
          _message = 'Recording… release to send';
        });
      }
      if (!_pointerHeld) {
        await _finishRecording(send: _sendAfterPointerEnd);
      }
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyError(error));
    } finally {
      _startingRecording = false;
    }
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_recording || _finishingRecording) return;
    _finishingRecording = true;
    _recordingTimer?.cancel();
    _recordingWatch.stop();
    final durationMs = _recordingWatch.elapsedMilliseconds.clamp(
      0,
      _maxVoiceDuration.inMilliseconds,
    );
    if (mounted) {
      setState(() {
        _recording = false;
        _busy = send;
        _message = send ? 'Sending voice nudge…' : null;
      });
    }

    String? path;
    try {
      path = await _recorder.stop();
      if (!send || path == null) return;
      if (durationMs < 250) {
        if (mounted) setState(() => _message = 'Hold a little longer to record.');
        return;
      }
      final file = File(path);
      final bytes = await file.readAsBytes();
      await _repository.sendVoice(
        groupId: widget.group.groupId,
        target: _target,
        audio: bytes,
        durationMs: durationMs,
      );
      if (mounted) setState(() => _message = 'Voice nudge sent');
    } catch (error) {
      if (mounted) setState(() => _message = _friendlyError(error));
    } finally {
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {
          // The OS cache cleaner is the final fallback.
        }
      }
      _recordingWatch.reset();
      _finishingRecording = false;
      if (mounted) {
        setState(() {
          _busy = false;
          _elapsed = Duration.zero;
        });
      }
    }
  }

  String _friendlyError(Object error) {
    if (error is NudgeDeliveryException) return error.message;
    if (error is ApiException && error.code == 'nudge_rate_limited') {
      return error.message;
    }
    final text = error.toString();
    if (text.contains('nudge_rate_limited')) {
      return 'Nudge limit reached. Please wait before trying again.';
    }
    if (text.contains('voice_nudge_too_large')) {
      return 'Recording was too large. Try again.';
    }
    return 'Couldn’t send the nudge. Check your connection.';
  }

  @override
  Widget build(BuildContext context) {
    final progress = (_elapsed.inMilliseconds / _maxVoiceDuration.inMilliseconds)
        .clamp(0.0, 1.0);
    return Scaffold(
      backgroundColor: const Color(0xff0d0d0d),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text('Nudge · ${widget.group.name}'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
          children: [
            Text(
              'Who should receive it?',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                ChoiceChip(
                  label: const Text('Everyone'),
                  selected: _target.targetScope == 'all_friends',
                  onSelected: (_) => setState(
                    () => _target = const NudgeTarget.allFriends(),
                  ),
                ),
                for (final friend in _friends)
                  ChoiceChip(
                    label: Text(friend.displayName),
                    selected: _target.targetUserId == friend.userId,
                    onSelected: (_) => setState(
                      () => _target = NudgeTarget.singleFriend(friend.userId),
                    ),
                  ),
              ],
            ),
            if (_friends.isEmpty) ...[
              const SizedBox(height: 12),
              const Text(
                'Add a friend to this group before sending a nudge.',
                style: TextStyle(color: Colors.white60),
              ),
            ],
            const SizedBox(height: 28),
            _NudgeCard(
              icon: Icons.notifications_active_outlined,
              title: 'Push notification',
              subtitle: 'A normal notification asking them to come online.',
              child: FilledButton(
                onPressed: _canSend ? _sendPush : null,
                child: const Text('Send notification'),
              ),
            ),
            const SizedBox(height: 14),
            _NudgeCard(
              icon: Icons.ring_volume_outlined,
              title: 'Ring nudge',
              subtitle: 'Plays while the Android phone is locked or the app process is closed.',
              child: Wrap(
                spacing: 10,
                children: [
                  for (final seconds in const [3, 5, 10])
                    OutlinedButton(
                      onPressed: _canSend ? () => _sendRing(seconds) : null,
                      child: Text('$seconds sec'),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _NudgeCard(
              icon: Icons.mic_none_rounded,
              title: 'Voice nudge',
              subtitle: 'Press and hold. Your recording is capped at 6 seconds and sent on release.',
              child: Center(
                child: Listener(
                  onPointerDown: (_) {
                    _pointerHeld = true;
                    _sendAfterPointerEnd = true;
                    unawaited(_beginRecording());
                  },
                  onPointerUp: (_) {
                    _pointerHeld = false;
                    _sendAfterPointerEnd = true;
                    unawaited(_finishRecording(send: true));
                  },
                  onPointerCancel: (_) {
                    _pointerHeld = false;
                    _sendAfterPointerEnd = false;
                    unawaited(_finishRecording(send: false));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      color: _recording ? widget.accent : const Color(0xff202020),
                      shape: BoxShape.circle,
                      boxShadow: _recording
                          ? [BoxShadow(color: widget.accent.withValues(alpha: 0.35), blurRadius: 26)]
                          : null,
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(6),
                          child: CircularProgressIndicator(
                            value: _recording ? progress : 0,
                            strokeWidth: 4,
                            color: Colors.white,
                            backgroundColor: Colors.white24,
                          ),
                        ),
                        Icon(
                          _recording ? Icons.mic_rounded : Icons.mic_none_rounded,
                          size: 42,
                          color: _recording ? Colors.black : Colors.white,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            if (_busy) ...[
              const SizedBox(height: 20),
              LinearProgressIndicator(color: widget.accent),
            ],
            if (_message != null) ...[
              const SizedBox(height: 16),
              Text(
                _message!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _NudgeCard extends StatelessWidget {
  const _NudgeCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff171717),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Colors.white70),
                const SizedBox(width: 10),
                Text(title, style: Theme.of(context).textTheme.titleMedium),
              ],
            ),
            const SizedBox(height: 8),
            Text(subtitle, style: const TextStyle(color: Colors.white60)),
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}
