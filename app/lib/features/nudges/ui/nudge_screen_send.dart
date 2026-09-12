part of 'nudge_screen.dart';

mixin _NudgeSheetSend on _NudgeSheetStateBase, _NudgeSheetDelivery {
  Duration _cooldownRemaining(NudgeKind kind) => _cooldowns.remaining(kind);

  String _cooldownLabel(Duration remaining) {
    final seconds = remaining.inMilliseconds / 1000;
    return seconds <= 1 ? 'wait 1s' : 'wait ${seconds.ceil()}s';
  }

  // Live session holds the hardware mic — voice record is blocked.
  bool get _liveMicBlocksVoice => widget.isLiveMicrophoneInUse?.call() ?? false;

  // Block back/barrier/drag for the whole press-and-hold (incl. post-cap).
  bool get _blockDismissWhileHolding =>
      _pointerHeld || _voiceHoldActive || _startingRecording;

  // ── 1. Ring ──────────────────────────────────────────────────────────────

  Future<void> _sendRing({required int durationSeconds}) async {
    if (_cooldownRemaining(NudgeKind.ring) > Duration.zero) return;
    _lastSentNudgeKind = NudgeKind.ring;
    _showConfirmingText = true;
    await _send(
      () => _repository.sendRing(
        groupId: widget.group.groupId,
        target: _effectiveTarget(),
        durationSeconds: durationSeconds,
      ),
      kind: NudgeKind.ring,
      awaitsDeliveryConfirmation: true,
      waitingMessage: 'Delivering ring nudge\u2026',
    );
  }

  // ── 2. Push ──────────────────────────────────────────────────────────────

  Future<void> _sendPush() async {
    if (_cooldownRemaining(NudgeKind.push) > Duration.zero) return;
    _lastSentNudgeKind = NudgeKind.push;
    _showConfirmingText = true;
    await _send(
      () => _repository.sendPush(
        groupId: widget.group.groupId,
        target: _effectiveTarget(),
      ),
      kind: NudgeKind.push,
      awaitsDeliveryConfirmation: true,
      waitingMessage: 'Delivering ring nudge\u2026',
    );
  }

  NudgeTarget _effectiveTarget() {
    final selected = _nudgeableFriends
        .where((f) => _selectedUserIds.contains(f.userId))
        .map((f) => f.userId)
        .toList(growable: false);
    if (selected.isEmpty || selected.length == _nudgeableFriends.length) {
      return const NudgeTarget.allFriends();
    }
    if (selected.length == 1) {
      return NudgeTarget.singleFriend(selected.first);
    }
    return NudgeTarget.selectedFriends(selected);
  }

  /// Requests microphone permission so a later background auto-connect can
  /// start the LiveKit session without showing a foreground dialog. No-op if
  /// it is already granted or the platform cannot request it right now.
  Future<void> _ensureMicrophonePermission() async {
    try {
      final status = await Permission.microphone.request();
      if (!status.isGranted) {
        LogManager.log(
          LogLevel.warn,
          'NudgeService',
          'Microphone permission not granted at send time; background '
              'auto-connect may require reopening the app',
          groupId: widget.group.groupId,
        );
      }
    } catch (_) {
      // Best-effort — the normal go-online path still re-checks permission.
    }
  }

  Future<void> _send(
    Future<Object?> Function() action, {
    required NudgeKind kind,
    bool awaitsDeliveryConfirmation = false,
    String waitingMessage = '',
    bool silentSuccess = false,
  }) async {
    if (!_canSend) return;
    final expected = _recipientsForTarget();
    if (expected.isEmpty) {
      setState(() {
        _message = 'Everyone is already online.';
        _messageIsError = true;
        _messageIsWarning = false;
      });
      return;
    }
    // 1. Best-effort mic permission while still foreground
    unawaited(_ensureMicrophonePermission());
    setState(() {
      _busy = true;
      _message = null;
      _messageIsError = false;
      _messageIsWarning = false;
      _messagePending = false;
      _showDeliveryBadges = false;
      _repliesByUserId.clear();
    });
    _rtdbVolumeFeedback = MediaVolumeFeedback.none;
    try {
      final result = await action();
      _cooldowns.record(kind);
      if (!mounted) return;
      final acceptedExpected = _acceptedRecipients(result, expected);
      setState(() => _busy = false);
      if (awaitsDeliveryConfirmation && result is Map) {
        final eventId = result['notificationEventId']?.toString();
        if (eventId != null && eventId.isNotEmpty) {
          // 2. Await playback confirmation
          _scheduleSenderExpiry(eventId, acceptedExpected);
          await _prepareDeliveryWait(
            eventId: eventId,
            expected: acceptedExpected,
            waitingMessage: waitingMessage,
          );
          return;
        }
      }
      if (!awaitsDeliveryConfirmation && result is Map) {
        final eventId = result['notificationEventId']?.toString();
        if (eventId != null && eventId.isNotEmpty) {
          _lastEventId = eventId;
          _scheduleSenderExpiry(eventId, acceptedExpected);
        }
      }
      // Check aggregate send/failed counts before claiming success.
      if (!awaitsDeliveryConfirmation && result is Map<String, dynamic>) {
        final nudgeResult = NudgeResult.fromSendResponse(
          result,
          acceptedExpected.map((e) => e.userId).toList(growable: false),
        );
        if (!nudgeResult.isFullSuccess) {
          final message = nudgeResult.isFullFailure
              ? 'Nudge wasn\u2019t delivered to anyone in this group.'
              : 'Nudge wasn\u2019t delivered to ${nudgeResult.failedCount} of '
                    '${nudgeResult.totalRecipients} people.';
          unawaited(
            CrashlyticsService.recordNudgeFailure(
              error: StateError(message),
              failureReason: NudgeFailureReason.fcmNotDelivered,
              senderId: widget.currentUserId,
              groupId: widget.group.groupId,
              extras: {
                'failed_count': nudgeResult.failedCount,
                'total_recipients': nudgeResult.totalRecipients,
              },
            ),
          );
          unawaited(
            AnalyticsService.logNudgeFailed(
              groupId: widget.group.groupId,
              kind: _lastSentNudgeKind?.name,
              failureReason: NudgeReachability.deviceUnreachable,
              deliveryMethod: 'fcm',
            ),
          );
          OperationalLog.record(
            event: OperationalLog.eventNudgeFailed,
            eventType: OperationalLog.eventTypeNudge,
            status: NudgeReachability.deviceUnreachable,
            error: 'fcm_not_delivered',
            sender: widget.currentUserId,
            groupId: widget.group.groupId,
            nudgeId: _lastEventId,
            level: LogLevel.error,
            debugMetadata: {
              'send_status': 'partial_or_failed',
              'failed_count': nudgeResult.failedCount,
              'total_recipients': nudgeResult.totalRecipients,
            },
          );
          NudgeFailureMemory.instance.record(
            widget.group.groupId,
            nudgeResult.isFullFailure
                ? NudgeErrorSeverity.full
                : NudgeErrorSeverity.partial,
            message,
          );
          _recordLastStatus(LastNudgeStatus.failed, message);
          setState(() {
            _message = message;
            _messageIsError = true;
            _messageIsWarning = false;
            _messagePending = false;
          });
          _scheduleAutoDismiss();
          return;
        }
      }

      if (silentSuccess) {
        // Push/PN: no delivery confirmation, no volume badges (spec).
        // Still seed recipient signifiers so decline/snooze can land later.
        NudgeFailureMemory.instance.clearGroup(widget.group.groupId);
        _expectedRecipients
          ..clear()
          ..addEntries(acceptedExpected.map((e) => MapEntry(e.userId, e)));
        final signifiers = [
          for (final pending in acceptedExpected)
            LastNudgeRecipientSignifier(
              userId: pending.userId,
              displayName: pending.displayName,
              failed: false,
            ),
        ];
        _recordLastStatus(
          LastNudgeStatus.sent,
          'Sent',
          eventId: _lastEventId,
          signifiers: signifiers,
        );
        setState(() {
          _message = null;
          _messageIsError = false;
          _messageIsWarning = false;
          _messagePending = false;
        });
        _scheduleAutoDismiss();
      } else {
        await _showImmediateSendOutcome(acceptedExpected);
      }
    } catch (error, stack) {
      final cancelled = error.toString().toLowerCase().contains('cancel');
      final expectedDelivery = error is NudgeDeliveryException;
      if (!cancelled && !expectedDelivery) {
        final reachability = NudgeReachability.fromSendError(error);
        unawaited(
          AnalyticsService.logNudgeFailed(
            groupId: widget.group.groupId,
            kind: _lastSentNudgeKind?.name,
            failureReason: reachability,
            deliveryMethod: 'fcm',
          ),
        );
        OperationalLog.record(
          event: OperationalLog.eventNudgeFailed,
          eventType: OperationalLog.eventTypeNudge,
          status: reachability,
          error: error.toString(),
          sender: widget.currentUserId,
          groupId: widget.group.groupId,
          level: LogLevel.error,
          debugMetadata: {'send_status': 'failed'},
        );
        unawaited(
          CrashlyticsService.recordNudgeFailure(
            error: error,
            stack: stack,
            failureReason:
                error is ApiException && error.code == 'permission_denied'
                ? NudgeFailureReason.permissionDeniedFirebase
                : NudgeFailureReason.unknown,
            senderId: widget.currentUserId,
            groupId: widget.group.groupId,
          ),
        );
      }
      if (!mounted) return;
      final rateLimited =
          error is ApiException && error.code == 'nudge_rate_limited';
      final message = rateLimited
          ? error.message
          : _friendlyError(error, recipients: expected);
      if (!cancelled && !rateLimited) {
        NudgeFailureMemory.instance.record(
          widget.group.groupId,
          NudgeErrorSeverity.full,
          message,
        );
      }
      setState(() {
        _message = message;
        _messageIsError = true;
        _messageIsWarning = false;
        _busy = false;
      });
    }
  }

  Future<void> _showImmediateSendOutcome(
    List<_PendingRecipient> expected,
  ) async {
    if (mounted) {
      setState(() {
        _message = 'Sent\u2026';
        _messageIsError = false;
        _messageIsWarning = false;
        _messagePending = true;
      });
    }
    final feedback = await _loadVolumeFeedback(expected);
    if (!mounted) return;
    _rtdbVolumeFeedback = feedback;
    if (feedback.hasWarnings) {
      NudgeFailureMemory.instance.clearGroup(widget.group.groupId);
      _recordLastStatus(
        _statusForVolumeWarnings(feedback),
        feedback.joinedWarnings,
      );
      setState(() {
        _message = feedback.joinedWarnings;
        _messageIsError = false;
        _messageIsWarning = true;
        _messagePending = false;
      });
    } else {
      final successMessage = MediaVolumeFeedback.successMessage(
        recipientCount: expected.length,
        singleFirstName: expected.length == 1
            ? mediaVolumeFirstName(expected.first.displayName)
            : null,
      );
      NudgeFailureMemory.instance.clearGroup(widget.group.groupId);
      _recordLastStatus(LastNudgeStatus.sent, successMessage);
      setState(() {
        _message = successMessage;
        _messageIsError = false;
        _messageIsWarning = false;
        _messagePending = false;
      });
    }
    _scheduleAutoDismiss();
  }

  LastNudgeStatus _statusForVolumeWarnings(MediaVolumeFeedback feedback) {
    final anyMuted = feedback.bandsByUserId.values.any(
      (band) => band == MediaVolumeBand.muted,
    );
    return anyMuted ? LastNudgeStatus.volumeMuted : LastNudgeStatus.volumeLow;
  }

  // ── 3. Voice record ─────────────────────────────────────────────────────

  void _onVoiceHoldEnded(bool send) {
    if (!mounted) return;
    if (!_pointerHeld &&
        !_recording &&
        !_startingRecording &&
        !_stoppingAtCap &&
        _pendingVoicePath == null) {
      return;
    }
    setState(() {
      _pointerHeld = false;
      _sendAfterPointerEnd = send;
    });
    if (_pendingVoicePath != null) {
      unawaited(_commitPendingVoice(send: send));
      return;
    }
    if (_stoppingAtCap) {
      // Mic flush in flight — commit once the path is ready.
      return;
    }
    unawaited(_finishRecording(send: send));
  }

  Future<void> _beginRecording() async {
    if (!_canSend || _startingRecording) return;
    if (_cooldownRemaining(NudgeKind.voice) > Duration.zero) return;
    if (_liveMicBlocksVoice) {
      if (mounted) {
        setState(() {
          _message = 'Mute your mic first to send a voice nudge.';
          _messageIsError = false;
          _messageIsWarning = true;
          _messagePending = false;
        });
      }
      return;
    }
    _startingRecording = true;
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) {
          setState(() {
            _message = 'Microphone permission is required.';
            _messageIsError = true;
            _messageIsWarning = false;
          });
        }
        return;
      }
      final file = File(
        '${Directory.systemTemp.path}/one_one_voice_${DateTime.now().microsecondsSinceEpoch}.${VoiceNudgeAudio.fileExtension}',
      );
      await _recorder.start(VoiceNudgeAudio.recordConfig, path: file.path);
      if (!mounted) {
        _voiceUploadReservation = null;
        await _recorder.stop();
        return;
      }
      _recordingWatch
        ..reset()
        ..start();
      _recordingTimer?.cancel();
      _recordingCapTimer?.cancel();
      // Cap only stops capture — send/discard waits for finger release so the
      // user can still swipe-up to delete after the max duration.
      _recordingCapTimer = Timer(VoiceNudgeAudio.maxRecordingDuration, () {
        unawaited(_stopRecordingAtCap());
      });
      _voiceRequestId = const Uuid().v4();
      _voiceNudgeId = null;
      _voiceConfirmationLogged = false;
      // Reserve the signed write URL while the user holds — the backend
      // recipient lookup (~4s on groups) finishes before record-end.
      _voiceUploadReservation = _repository.initiateVoiceUpload(
        groupId: widget.group.groupId,
        target: _effectiveTarget(),
        durationMs: VoiceNudgeAudio.maxRecordingDuration.inMilliseconds,
      );
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'VOICE_NUDGE_RECORD_START nudgeId=$_voiceRequestId '
            'encoder=aacLc bitRate=${VoiceNudgeAudio.bitRate} '
            'sampleRate=${VoiceNudgeAudio.sampleRate} '
            'channels=${VoiceNudgeAudio.numChannels} '
            'capMs=${VoiceNudgeAudio.maxRecordingDuration.inMilliseconds} '
            'uploadReserveAtStart=true',
        groupId: widget.group.groupId,
      );
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 50), (_) {
        if (!mounted || !_recording) return;
        setState(() => _elapsed = _recordingWatch.elapsed);
      });
      setState(() {
        _recording = true;
        _elapsed = Duration.zero;
        _message = _swipeCancel.recordingStatusMessage(isRecording: true);
        _messageIsError = false;
        _messageIsWarning = _swipeCancel.isArmed;
        _messagePending = !_swipeCancel.isArmed;
      });
      if (!_pointerHeld) {
        await _finishRecording(send: _sendAfterPointerEnd);
      }
    } catch (error) {
      _voiceUploadReservation = null;
      if (mounted) {
        setState(() {
          _message = _friendlyError(error);
          _messageIsError = true;
          _messageIsWarning = false;
        });
      }
    } finally {
      _startingRecording = false;
    }
  }

  /// Stops the mic at max duration without sending. Hold stays active so the
  /// user can still swipe-cancel; release commits or discards.
  Future<void> _stopRecordingAtCap() async {
    if (!_recording || _finishingRecording || _stoppingAtCap) return;
    _stoppingAtCap = true;
    _recordingTimer?.cancel();
    _recordingCapTimer?.cancel();
    _recordingWatch.stop();
    final actualDurationMs = _recordingWatch.elapsedMilliseconds;
    final durationMs = actualDurationMs.clamp(
      0,
      VoiceNudgeAudio.maxAcceptedDurationMs,
    );
    LogManager.log(
      LogLevel.info,
      'NudgeService',
      'VOICE_NUDGE_RECORD_CAP nudgeId=${_voiceRequestId ?? '-'} '
          'durationMs=$actualDurationMs '
          'capMs=${VoiceNudgeAudio.maxRecordingDuration.inMilliseconds} '
          'awaitingRelease=true',
      groupId: widget.group.groupId,
    );
    if (mounted) {
      setState(() {
        _recording = false;
        _elapsed = VoiceNudgeAudio.maxRecordingDuration;
        _message = _swipeCancel.recordingStatusMessage(
          isRecording: true,
          capped: true,
        );
        _messageIsError = false;
        _messageIsWarning = _swipeCancel.isArmed;
        _messagePending = !_swipeCancel.isArmed;
      });
    }

    String? path;
    try {
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'VOICE_NUDGE_COMPRESSION_START nudgeId=${_voiceRequestId ?? '-'}',
        groupId: widget.group.groupId,
      );
      final stopWatch = Stopwatch()..start();
      path = await _recorder.stop();
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'VOICE_NUDGE_COMPRESSION_END nudgeId=${_voiceRequestId ?? '-'} '
            'elapsedMs=${stopWatch.elapsedMilliseconds} path=${path != null}',
        groupId: widget.group.groupId,
      );
    } catch (error) {
      _stoppingAtCap = false;
      _voiceUploadReservation = null;
      if (mounted) {
        setState(() {
          _message = _friendlyError(error);
          _messageIsError = true;
          _messageIsWarning = false;
          _messagePending = false;
        });
      }
      return;
    }

    if (!mounted) {
      _stoppingAtCap = false;
      if (path != null) {
        try {
          await File(path).delete();
        } catch (_) {}
      }
      return;
    }

    // Finger already up while the mic was flushing — commit with the
    // decision captured at release (or default send).
    if (!_pointerHeld) {
      _stoppingAtCap = false;
      _pendingVoicePath = path;
      _pendingVoiceDurationMs = durationMs;
      await _commitPendingVoice(send: _sendAfterPointerEnd);
      return;
    }

    setState(() {
      _stoppingAtCap = false;
      _pendingVoicePath = path;
      _pendingVoiceDurationMs = durationMs;
    });
  }

  Future<void> _commitPendingVoice({required bool send}) async {
    if (_finishingRecording) return;
    final path = _pendingVoicePath;
    final durationMs = _pendingVoiceDurationMs;
    _pendingVoicePath = null;
    _pendingVoiceDurationMs = 0;
    _stoppingAtCap = false;
    await _completeVoiceClip(
      send: send,
      path: path,
      durationMs: durationMs,
      alreadyStopped: true,
    );
  }

  Future<void> _finishRecording({required bool send}) async {
    if (!_recording || _finishingRecording) return;
    await _completeVoiceClip(
      send: send,
      path: null,
      durationMs: _recordingWatch.elapsedMilliseconds.clamp(
        0,
        VoiceNudgeAudio.maxAcceptedDurationMs,
      ),
      alreadyStopped: false,
    );
  }

  Future<void> _completeVoiceClip({
    required bool send,
    required String? path,
    required int durationMs,
    required bool alreadyStopped,
  }) async {
    if (_finishingRecording) return;
    _finishingRecording = true;
    _swipeCancel.reset();
    _recordingTimer?.cancel();
    _recordingCapTimer?.cancel();
    if (!alreadyStopped) {
      _recordingWatch.stop();
    }
    // Recording feedback stays on a fixed default — Settings haptics only
    // apply to incoming voice-nudge playback.
    unawaited(
      send ? HapticFeedback.selectionClick() : HapticFeedback.mediumImpact(),
    );
    final actualDurationMs = alreadyStopped
        ? durationMs
        : _recordingWatch.elapsedMilliseconds;
    final clampedDurationMs = actualDurationMs.clamp(
      0,
      VoiceNudgeAudio.maxAcceptedDurationMs,
    );
    // Start the end-to-end clock at record-end: everything below (flush,
    // upload, dispatch, receiver download/decode/playback, confirmation) must
    // fit within the target window.
    _voiceNudgeWatch
      ..reset()
      ..start();
    LogManager.log(
      LogLevel.info,
      'NudgeService',
      'VOICE_NUDGE_RECORD_END nudgeId=${_voiceRequestId ?? '-'} '
          'durationMs=$actualDurationMs send=$send '
          'capMs=${VoiceNudgeAudio.maxRecordingDuration.inMilliseconds}',
      groupId: widget.group.groupId,
    );
    if (mounted) {
      setState(() {
        _recording = false;
        _stoppingAtCap = false;
        _busy = send;
        _sendingVoice = send;
        // Step 1: "Voice nudge sending"
        _message = send ? 'Voice nudge sending\u2026' : 'Recording discarded';
        _messageIsError = false;
        _messageIsWarning = !send;
        _messagePending = send;
        _showDeliveryBadges = false;
      });
    }

    var clipPath = path;
    var sent = false;
    String? voiceEventId;
    final minMs = VoiceNudgeAudio.minRecordingDuration.inMilliseconds;
    final uploadReservation = send && clampedDurationMs >= minMs
        ? _voiceUploadReservation
        : null;
    _voiceUploadReservation = null;
    try {
      if (!alreadyStopped) {
        // AAC-LC encoding happens inside the recorder while recording; the
        // stop() call only flushes/finalizes the M4A container. This is the
        // single measurable "compression" step on the sender.
        LogManager.log(
          LogLevel.info,
          'NudgeService',
          'VOICE_NUDGE_COMPRESSION_START nudgeId=${_voiceRequestId ?? '-'}',
          groupId: widget.group.groupId,
        );
        final stopWatch = Stopwatch()..start();
        clipPath = await _recorder.stop();
        LogManager.log(
          LogLevel.info,
          'NudgeService',
          'VOICE_NUDGE_COMPRESSION_END nudgeId=${_voiceRequestId ?? '-'} '
              'elapsedMs=${stopWatch.elapsedMilliseconds} '
              'path=${clipPath != null}',
          groupId: widget.group.groupId,
        );
      }
      if (!send || clipPath == null) return;
      if (clampedDurationMs < minMs) {
        if (mounted) {
          setState(() {
            _message = 'Hold a little longer to record.';
            _messageIsError = true;
            _messageIsWarning = false;
          });
        }
        return;
      }
      final file = File(clipPath);
      // Overlap reading the M4A off disk with the upload-url reservation that
      // was kicked off at record-start — avoids serializing on slow paths.
      Uint8List audio;
      Map<String, dynamic>? initiatedUpload;
      try {
        if (uploadReservation != null) {
          final parallel = await Future.wait<Object?>([
            file.readAsBytes(),
            uploadReservation,
          ]);
          audio = parallel.first as Uint8List;
          if (parallel.length > 1 && parallel[1] is Map) {
            initiatedUpload = parallel[1] as Map<String, dynamic>;
          }
        } else {
          audio = await file.readAsBytes();
        }
      } catch (_) {
        audio = await file.readAsBytes();
        initiatedUpload = null;
      }
      final response = await _repository.sendVoice(
        groupId: widget.group.groupId,
        target: _effectiveTarget(),
        audio: audio,
        durationMs: clampedDurationMs,
        initiatedUpload: initiatedUpload,
      );
      _cooldowns.record(NudgeKind.voice);
      sent = true;
      voiceEventId = response['notificationEventId']?.toString();
      _voiceNudgeId = voiceEventId;
      LogManager.log(
        LogLevel.info,
        'NudgeService',
        'VOICE_NUDGE_SEND_ACK nudgeId=${voiceEventId ?? '-'} '
            'clientRequestId=${_voiceRequestId ?? '-'} '
            'elapsedSinceRecordEndMs=${_voiceNudgeWatch.elapsedMilliseconds}',
        groupId: widget.group.groupId,
      );
      _expectedRecipients
        ..clear()
        ..addEntries(
          _acceptedRecipients(
            response,
            _recipientsForTarget(),
          ).map((recipient) => MapEntry(recipient.userId, recipient)),
        );
    } catch (error) {
      if (mounted) {
        setState(() {
          _message = _friendlyError(
            error,
            recipients: _recipientsForTarget(),
          );
          _messageIsError = true;
          _messageIsWarning = false;
        });
      }
    } finally {
      if (clipPath != null) {
        try {
          await File(clipPath).delete();
        } catch (_) {}
      }
      _recordingWatch.reset();
      _pendingVoicePath = null;
      _pendingVoiceDurationMs = 0;
      _finishingRecording = false;
      if (mounted) {
        setState(() {
          _busy = false;
          _sendingVoice = false;
          _elapsed = Duration.zero;
        });
        if (sent && voiceEventId != null && voiceEventId.isNotEmpty) {
          // Voice nudge: delivering → started playing → confirmed summary.
          _lastSentNudgeKind = NudgeKind.voice;
          _showConfirmingText = true;
          await _prepareDeliveryWait(
            eventId: voiceEventId,
            expected: _expectedRecipients.values.toList(growable: false),
            waitingMessage: 'Delivering voice nudge\u2026',
          );
        } else if (sent) {
          await _showImmediateSendOutcome(
            _expectedRecipients.values.toList(growable: false),
          );
        }
      }
    }
  }

  String _friendlyError(
    Object error, {
    List<_PendingRecipient> recipients = const [],
  }) {
    final names = recipients.map((r) => r.displayName).toList(growable: false);
    if (error is ApiException && error.code == 'nudge_rate_limited') {
      return error.message;
    }
    if (error is ApiException && error.code == 'no_recipient_devices') {
      _logRecipientUnreachable(
        reason: NudgeDeliveryFailureCode.noRegisteredDevice,
        recipients: recipients,
        detail: error.message,
      );
      return UserFacingCopy.recipientDeviceUnavailableFor(names);
    }
    if (error is NudgeDeliveryException) {
      switch (error.code) {
        case NudgeDeliveryFailureCode.noRegisteredDevice:
          _logRecipientUnreachable(
            reason: NudgeDeliveryFailureCode.noRegisteredDevice,
            recipients: recipients,
            detail: error.message,
          );
          return UserFacingCopy.recipientDeviceUnavailableFor(names);
        case NudgeDeliveryFailureCode.fcmNotDelivered:
          _logRecipientUnreachable(
            reason: NudgeDeliveryFailureCode.fcmNotDelivered,
            recipients: recipients,
            detail: error.message,
          );
          return UserFacingCopy.notificationDeliveryFailureFor(names);
        case NudgeDeliveryFailureCode.noRecipients:
          _logRecipientUnreachable(
            reason: NudgeDeliveryFailureCode.noRecipients,
            recipients: recipients,
            detail: error.message,
          );
          break;
      }
      return UserFacingCopy.sanitize(error.message);
    }
    final text = error.toString();
    if (text.contains('no_recipient_devices')) {
      _logRecipientUnreachable(
        reason: NudgeDeliveryFailureCode.noRegisteredDevice,
        recipients: recipients,
        detail: text,
      );
      return UserFacingCopy.recipientDeviceUnavailableFor(names);
    }
    if (UserFacingCopy.containsInternalIdentifier(text)) {
      _logRecipientUnreachable(
        reason: NudgeDeliveryFailureCode.fcmNotDelivered,
        recipients: recipients,
        detail: text,
      );
      return UserFacingCopy.notificationDeliveryFailureFor(names);
    }
    if (text.contains('nudge_rate_limited')) {
      return 'Nudge limit reached. Please wait before trying again.';
    }
    if (text.contains('voice_nudge_too_large')) {
      return 'Recording was too large. Try again.';
    }
    return 'Couldn\u2019t send the nudge. Check your connection.';
  }

  void _logRecipientUnreachable({
    required String reason,
    required List<_PendingRecipient> recipients,
    String? detail,
  }) {
    final named = recipients.isEmpty
        ? '-'
        : recipients
              .map((r) => '${r.displayName}:${r.userId}')
              .join(', ');
    LogManager.log(
      LogLevel.warn,
      'NudgeService',
      'NUDGE_RECIPIENT_UNREACHABLE reason=$reason '
          'likely_cause=wrong_account_or_missing_fcm '
          'recipients=[$named] '
          'detail=${detail ?? '-'}',
      groupId: widget.group.groupId,
    );
  }
}
