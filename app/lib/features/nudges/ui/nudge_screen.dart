import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:record/record.dart';

import '../../../core/network/api_client.dart';
import '../../groups/models/group_member_summary.dart';
import '../../groups/models/group_summary.dart';
import '../../identity/ui/profile_avatar.dart';
import '../data/nudge_repository.dart';
import '../nudge_cooldowns.dart';

Future<void> showNudgeBottomSheet(
  BuildContext context, {
  required GroupSummary group,
  required String currentUserId,
  required List<GroupMemberSummary> members,
  required Color accent,
  bool hapticsEnabled = true,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _QuickNudgeSheet(
      group: group,
      currentUserId: currentUserId,
      members: members,
      accent: accent,
      hapticsEnabled: hapticsEnabled,
    ),
  );
}

class _QuickNudgeSheet extends StatefulWidget {
  const _QuickNudgeSheet({
    required this.group,
    required this.currentUserId,
    required this.members,
    required this.accent,
    required this.hapticsEnabled,
  });

  final GroupSummary group;
  final String currentUserId;
  final List<GroupMemberSummary> members;
  final Color accent;
  final bool hapticsEnabled;

  @override
  State<_QuickNudgeSheet> createState() => _QuickNudgeSheetState();
}

class _QuickNudgeSheetState extends State<_QuickNudgeSheet> {
  static const _maxVoiceDuration = Duration(seconds: 6);

  final NudgeRepository _repository = NudgeRepository();
  final AudioRecorder _recorder = AudioRecorder();
  final Stopwatch _recordingWatch = Stopwatch();
  final NudgeCooldownTracker _cooldowns = NudgeCooldownTracker.instance;
  NudgeTarget _target = const NudgeTarget.allFriends();
  Timer? _recordingTimer;
  Timer? _cooldownTicker;
  bool _recording = false;
  bool _startingRecording = false;
  bool _finishingRecording = false;
  bool _pointerHeld = false;
  bool _sendAfterPointerEnd = true;
  bool _busy = false;
  bool _sendingVoice = false;
  Duration _elapsed = Duration.zero;
  String? _message;
  bool _messageIsError = false;

  @override
  void initState() {
    super.initState();
    // Cheap periodic tick so per-type cooldown countdowns shown in this
    // short-lived sheet stay live without a dedicated stream per chip.
    _cooldownTicker = Timer.periodic(const Duration(milliseconds: 500), (_) {
      if (mounted) setState(() {});
    });
  }

  List<GroupMemberSummary> get _friends => widget.members
      .where(
        (member) =>
            member.userId != widget.currentUserId &&
            member.memberState == 'active',
      )
      .toList(growable: false);

  bool get _canSend =>
      _friends.isNotEmpty &&
      !_busy &&
      !_startingRecording &&
      !_finishingRecording &&
      !_recording;

  @override
  void dispose() {
    _recordingTimer?.cancel();
    _cooldownTicker?.cancel();
    if (_recording) unawaited(_recorder.stop());
    unawaited(_recorder.dispose());
    super.dispose();
  }

  /// Remaining local cooldown for [kind]. Purely a UX affordance — the
  /// backend is the authoritative enforcer and still returns
  /// `nudge_rate_limited` if this local check is somehow bypassed.
  Duration _cooldownRemaining(NudgeKind kind) => _cooldowns.remaining(kind);

  String _cooldownLabel(Duration remaining) {
    final seconds = remaining.inMilliseconds / 1000;
    return seconds <= 1 ? 'wait 1s' : 'wait ${seconds.ceil()}s';
  }

  Future<void> _sendRing(int seconds) async {
    if (_cooldownRemaining(NudgeKind.ring) > Duration.zero) return;
    await _send(
      () => _repository.sendRing(
        groupId: widget.group.groupId,
        target: _target,
        durationSeconds: seconds,
      ),
      '${seconds}s ring sent',
      kind: NudgeKind.ring,
    );
  }

  Future<void> _sendPush() async {
    if (_cooldownRemaining(NudgeKind.push) > Duration.zero) return;
    await _send(
      () =>
          _repository.sendPush(groupId: widget.group.groupId, target: _target),
      'Notification sent',
      kind: NudgeKind.push,
    );
  }

  Future<void> _send(
    Future<Object?> Function() action,
    String successMessage, {
    required NudgeKind kind,
  }) async {
    if (!_canSend) return;
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
    });
    try {
      await action();
      _cooldowns.record(kind);
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
          : 'Couldn\u2019t send the nudge. Check your connection.';
      setState(() {
        _message = message;
        _messageIsError = true;
      });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _beginRecording() async {
    if (!_canSend || _startingRecording) return;
    if (_cooldownRemaining(NudgeKind.voice) > Duration.zero) return;
    _startingRecording = true;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          setState(() {
            _message = 'Microphone permission is required.';
            _messageIsError = true;
          });
        }
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
      // Second, slightly stronger pulse confirms recording actually started
      // (distinct from the immediate "press acknowledged" pulse on touch-down).
      if (widget.hapticsEnabled) unawaited(HapticFeedback.mediumImpact());
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
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
        _message = 'Recording… release to send';
        _messageIsError = false;
      });
      if (!_pointerHeld) {
        await _finishRecording(send: _sendAfterPointerEnd);
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _friendlyError(error);
          _messageIsError = true;
        });
      }
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
        _sendingVoice = send;
        _message = send ? 'Sending voice nudge…' : null;
        _messageIsError = false;
      });
    }

    String? path;
    try {
      path = await _recorder.stop();
      if (!send || path == null) return;
      if (durationMs < 250) {
        if (mounted) {
          setState(() {
            _message = 'Hold a little longer to record.';
            _messageIsError = true;
          });
        }
        return;
      }
      final file = File(path);
      await _repository.sendVoice(
        groupId: widget.group.groupId,
        target: _target,
        audio: await file.readAsBytes(),
        durationMs: durationMs,
      );
      _cooldowns.record(NudgeKind.voice);
      if (mounted) {
        setState(() {
          _message = 'Voice nudge sent';
          _messageIsError = false;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _friendlyError(error);
          _messageIsError = true;
        });
      }
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
          _sendingVoice = false;
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
    final ringCooldown = _cooldownRemaining(NudgeKind.ring);
    final pushCooldown = _cooldownRemaining(NudgeKind.push);
    final voiceCooldown = _cooldownRemaining(NudgeKind.voice);
    final actionEnabled = _canSend;
    final ringEnabled = actionEnabled && ringCooldown <= Duration.zero;
    final pushEnabled = actionEnabled && pushCooldown <= Duration.zero;
    final voiceEnabled = _canSend && voiceCooldown <= Duration.zero;
    final recordingProgress =
        (_elapsed.inMilliseconds / _maxVoiceDuration.inMilliseconds).clamp(
          0.0,
          1.0,
        );
    final accent = widget.accent;

    return PopScope(
      canPop:
          !_busy && !_recording && !_startingRecording && !_finishingRecording,
      child: Material(
        color: const Color(0xff141414),
        borderRadius: BorderRadius.vertical(top: Radius.circular(28.r)),
        clipBehavior: Clip.antiAlias,
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.88,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Drag handle ──
                Center(
                  child: Padding(
                    padding: EdgeInsets.only(top: 10.h, bottom: 14.h),
                    child: Container(
                      width: 38.w,
                      height: 4.h,
                      decoration: BoxDecoration(
                        color: Colors.white24,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                ),

                // ── Header ──
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 0, 8.w, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Send a nudge',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18.sp,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            SizedBox(height: 2.h),
                            Text(
                              widget.group.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: Colors.white38,
                                fontSize: 12.sp,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        onPressed: _busy || _recording || _startingRecording
                            ? null
                            : () => Navigator.of(context).pop(),
                        icon: const Icon(Icons.close_rounded),
                        color: Colors.white38,
                        iconSize: 20.sp,
                        tooltip: 'Close',
                      ),
                    ],
                  ),
                ),

                SizedBox(height: 18.h),

                // ── Recipient picker ──
                SizedBox(
                  height: 80.h,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: EdgeInsets.symmetric(horizontal: 20.w),
                    children: [
                      _NudgeRecipient(
                        label: 'Everyone',
                        selected: _target.targetScope == 'all_friends',
                        accent: accent,
                        onTap: actionEnabled
                            ? () => setState(
                                () => _target = const NudgeTarget.allFriends(),
                              )
                            : null,
                        avatar: Container(
                          color: accent.withValues(alpha: 0.18),
                          child: Icon(
                            Icons.group_rounded,
                            color: accent,
                            size: 22.sp,
                          ),
                        ),
                      ),
                      for (final friend in _friends) ...[
                        SizedBox(width: 10.w),
                        _NudgeRecipient(
                          label: friend.displayName,
                          selected: _target.targetUserId == friend.userId,
                          accent: accent,
                          onTap: actionEnabled
                              ? () => setState(
                                  () => _target = NudgeTarget.singleFriend(
                                    friend.userId,
                                  ),
                                )
                              : null,
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

                SizedBox(height: 14.h),
                _SheetDivider(),

                // ── Quick ring (most subtle — listed first) ──
                Padding(
                  padding: EdgeInsets.symmetric(
                    horizontal: 20.w,
                    vertical: 13.h,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.vibration_rounded,
                        color: Colors.white38,
                        size: 17.sp,
                      ),
                      SizedBox(width: 10.w),
                      Text(
                        ringCooldown > Duration.zero
                            ? 'Quick ring · ${_cooldownLabel(ringCooldown)}'
                            : 'Quick ring',
                        style: TextStyle(
                          color: Colors.white54,
                          fontSize: 13.sp,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const Spacer(),
                      // Chips stay visible (only their enabled state changes)
                      // so an in-flight send never hides the duration picker —
                      // a generic spinner here previously replaced it.
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          for (final s in const [3, 5, 10]) ...[
                            if (s != 3) SizedBox(width: 6.w),
                            _RingChip(
                              seconds: s,
                              accent: accent,
                              enabled: ringEnabled,
                              onTap: () => _sendRing(s),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                _SheetDivider(),

                // ── Push notification (medium urgency — second) ──
                InkWell(
                  onTap: pushEnabled ? _sendPush : null,
                  child: Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: 20.w,
                      vertical: 14.h,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.notifications_none_rounded,
                          color: pushEnabled ? Colors.white70 : Colors.white24,
                          size: 20.sp,
                        ),
                        SizedBox(width: 12.w),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Push notification',
                                style: TextStyle(
                                  color: pushEnabled
                                      ? Colors.white
                                      : Colors.white24,
                                  fontSize: 14.sp,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Text(
                                pushCooldown > Duration.zero
                                    ? _cooldownLabel(pushCooldown)
                                    : 'Standard alert',
                                style: TextStyle(
                                  color: pushEnabled
                                      ? Colors.white38
                                      : Colors.white12,
                                  fontSize: 11.sp,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_rounded,
                          color: pushEnabled ? Colors.white24 : Colors.white12,
                          size: 16.sp,
                        ),
                      ],
                    ),
                  ),
                ),

                _SheetDivider(),

                // ── Voice message — recorded and sent inside this sheet ──
                Padding(
                  padding: EdgeInsets.fromLTRB(20.w, 16.h, 20.w, 18.h),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.mic_none_rounded,
                            color: voiceEnabled || _recording
                                ? accent
                                : Colors.white24,
                            size: 20.sp,
                          ),
                          SizedBox(width: 10.w),
                          Text(
                            'Voice nudge',
                            style: TextStyle(
                              color: voiceEnabled || _recording
                                  ? Colors.white
                                  : Colors.white24,
                              fontSize: 14.sp,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 5.h),
                      Text(
                        voiceCooldown > Duration.zero
                            ? 'Voice nudge sent recently — ${_cooldownLabel(voiceCooldown)}.'
                            : 'Press and hold the mic. Your recording is capped at 6 seconds and sent when you release.',
                        style: TextStyle(
                          color: voiceEnabled || _recording
                              ? Colors.white38
                              : Colors.white12,
                          fontSize: 11.sp,
                          height: 1.4,
                        ),
                      ),
                      SizedBox(height: 16.h),
                      Center(
                        child: Semantics(
                          button: true,
                          enabled: voiceEnabled,
                          label: _recording
                              ? 'Recording voice nudge, release to send'
                              : _sendingVoice
                              ? 'Sending voice nudge'
                              : 'Voice nudge, press and hold to record',
                          child: Listener(
                            onPointerDown: (_) {
                              if (!voiceEnabled) return;
                              // Immediate, subtle pulse the instant the press is
                              // registered — before we even know the recorder
                              // will start — so the touch feels acknowledged.
                              if (widget.hapticsEnabled) {
                                unawaited(HapticFeedback.lightImpact());
                              }
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
                              width: 104.r,
                              height: 104.r,
                              decoration: BoxDecoration(
                                color: _recording
                                    ? accent
                                    : _sendingVoice
                                    ? accent.withValues(alpha: 0.18)
                                    : const Color(0xff202020),
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: _recording || _sendingVoice
                                      ? accent
                                      : Colors.white.withValues(alpha: 0.09),
                                ),
                                boxShadow: _recording || _sendingVoice
                                    ? [
                                        BoxShadow(
                                          color: accent.withValues(alpha: 0.35),
                                          blurRadius: 26.r,
                                        ),
                                      ]
                                    : null,
                              ),
                              child: _sendingVoice
                                  ? _SendingVoicePulse(accent: accent)
                                  : Stack(
                                      fit: StackFit.expand,
                                      children: [
                                        Padding(
                                          padding: EdgeInsets.all(6.r),
                                          child: CircularProgressIndicator(
                                            value: _recording
                                                ? recordingProgress
                                                : 0,
                                            strokeWidth: 4.r,
                                            color: Colors.white,
                                            backgroundColor: Colors.white24,
                                          ),
                                        ),
                                        Icon(
                                          _recording
                                              ? Icons.mic_rounded
                                              : Icons.mic_none_rounded,
                                          size: 42.sp,
                                          color: _recording
                                              ? Colors.black
                                              : voiceEnabled
                                              ? Colors.white
                                              : Colors.white24,
                                        ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 9.h),
                      Center(
                        child: Text(
                          _recording
                              ? '${(_elapsed.inMilliseconds / 1000).toStringAsFixed(1)} / 6.0 sec'
                              : _sendingVoice
                              ? 'Sending…'
                              : 'Hold to record · release to send',
                          style: TextStyle(
                            color: _recording || _sendingVoice
                                ? accent
                                : Colors.white30,
                            fontSize: 10.sp,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Status / no-friends message ──
                if (_friends.isEmpty || _message != null) ...[
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 4.h, 20.w, 0),
                    child: _NudgeStatus(
                      message: _friends.isEmpty
                          ? 'Invite a friend before sending a nudge.'
                          : _message!,
                      isError: _friends.isEmpty || _messageIsError,
                    ),
                  ),
                ],

                SizedBox(height: 28.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Replaces the generic spinner previously shown while a voice nudge
/// uploads: a paper-plane glyph gently bobbing inside two staggered,
/// outward-fading ripples — reads as "transmitting" rather than "loading"
/// and keeps the mic button's footprint identical so nothing jumps around.
class _SendingVoicePulse extends StatefulWidget {
  const _SendingVoicePulse({required this.accent});

  final Color accent;

  @override
  State<_SendingVoicePulse> createState() => _SendingVoicePulseState();
}

class _SendingVoicePulseState extends State<_SendingVoicePulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;
        return Stack(
          alignment: Alignment.center,
          fit: StackFit.expand,
          children: [
            _ripple((t + 0.0) % 1.0),
            _ripple((t + 0.5) % 1.0),
            Transform.translate(
              offset: Offset(0, -3.r * math.sin(t * 2 * math.pi)),
              child: Icon(Icons.send_rounded, size: 32.sp, color: Colors.white),
            ),
          ],
        );
      },
    );
  }

  Widget _ripple(double progress) {
    final scale = 0.5 + progress * 0.85;
    final opacity = (1 - progress) * 0.5;
    return Opacity(
      opacity: opacity.clamp(0.0, 1.0),
      child: Transform.scale(
        scale: scale,
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 1.4),
          ),
        ),
      ),
    );
  }
}

// Thin sheet section divider
class _SheetDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Divider(
      color: Colors.white.withValues(alpha: 0.06),
      height: 1,
      indent: 20.w,
      endIndent: 20.w,
    );
  }
}

// Compact ring duration chip
class _RingChip extends StatelessWidget {
  const _RingChip({
    required this.seconds,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final int seconds;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: enabled
          ? accent.withValues(alpha: 0.12)
          : Colors.white.withValues(alpha: 0.04),
      borderRadius: BorderRadius.circular(10.r),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(10.r),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: 10.w, vertical: 6.h),
          child: Text(
            '${seconds}s',
            style: TextStyle(
              color: enabled ? accent : Colors.white24,
              fontSize: 12.sp,
              fontWeight: FontWeight.w700,
            ),
          ),
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
          width: 60.w,
          child: Column(
            children: [
              AnimatedContainer(
                duration: const Duration(milliseconds: 160),
                padding: EdgeInsets.all(2.r),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xff1e1e1e),
                  border: Border.all(
                    color: selected ? accent : Colors.transparent,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: SizedBox(width: 46.r, height: 46.r, child: avatar),
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
