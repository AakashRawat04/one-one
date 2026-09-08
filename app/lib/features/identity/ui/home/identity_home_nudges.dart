part of '../identity_home_screen.dart';

// 1. Consume pending Accept/Connect from the native bridge.
// 2. Prefetch LiveKit, process action, notify sender.
// 3. Incoming prompt hydrate / present / accept / decline.

mixin _IdentityHomeNudges on _IdentityHomeBase {
  @override
  Future<void> _takePendingNudgeAction() async {
    // 1. Pull Accept/Connect from native (or a deferred action).
    if (_nudgeActionInFlight) return;
    NudgeNotificationAction? action;
    try {
      action =
          _deferredNudgeAction ??
          await _nudgeActionBridge.takePendingNudgeAction();
      if (!mounted) return;
      if (action == null) {
        unawaited(_hydrateIncomingNudges());
        return;
      }
      if (_loadingGroups) {
        _deferredNudgeAction = action;
        return;
      }
      _deferredNudgeAction = null;
      if (action.isOpenOnly) {
        _nudgeInbox.upsert(
          ActiveNudge(
            nudgeId: action.eventId,
            groupId: action.groupId,
            senderId: action.senderUserId ?? '',
            sentAt: DateTime.now(),
          ),
        );
        await _hydrateIncomingNudges(
          preferGroupId: action.groupId,
          preferNudgeId: action.eventId,
        );
        return;
      }
      _nudgeActionInFlight = true;
      await _processNudgeAction(action);
    } catch (error) {
      // Banner taps only open the Accept/Decline prompt — never auto-join.
      // Don't surface the Accept-path error if hydrate/present failed.
      if (action != null && action.isOpenOnly) {
        if (mounted) {
          await _presentIncomingNudgePrompt(
            preferGroupId: action.groupId,
            preferNudgeId: action.eventId,
          );
        }
        return;
      }
      // Only defer while home data is still loading. Re-queuing after a
      // later failure would auto-connect on every subsequent foreground.
      if (action != null && _loadingGroups) {
        _deferredNudgeAction = action;
      }
      if (mounted) {
        setState(() => _message = 'Couldn’t process the nudge action.');
      }
    } finally {
      _nudgeActionInFlight = false;
    }
  }

  /// Fired when this device receives a nudge (FCM arrived / playback starting),
  /// before the user has tapped accept. Prefetches + warms the LiveKit
  /// connection so the accept -> connected path skips the token round-trip and
  /// the WebRTC/DNS/TLS warm-up.
  Future<void> _onNudgeReceived(String groupId) async {
    final group = _groups
        .where((candidate) => candidate.groupId == groupId)
        .firstOrNull;
    if (group == null) return;
    await _prefetchLiveKit(group: group);
  }

  /// Prefetches a LiveKit token and warms the local [Room]/DNS/TLS without
  /// connecting. Best-effort: any failure here is ignored because the real
  /// go-online path still performs a synchronous fallback.
  @override
  Future<void> _prefetchLiveKit({required GroupSummary group}) async {
    // Warm rooms always default to speaker; session connect reasserts this (E1).
    await LiveKitConnectionWarmer.instance.prefetch(
      repository: _onlineRepository,
      identity: _session,
      group: group,
      speakerOn: true,
    );
  }

  Future<void> _processNudgeAction(NudgeNotificationAction action) async {
    // 1. Deduplicate, resolve group, join (or switch) the room.
    if (_processedNudgeEventIds.contains(action.eventId)) {
      LogManager.log(
        LogLevel.info,
        'LiveKitManager',
        'Ignoring already-processed nudge action=${action.action} '
            'eventId=${action.eventId}',
        userId: _session.userId,
        groupId: action.groupId,
      );
      return;
    }
    // Mark before awaiting goOnline so a parallel FCM/native path with the
    // same eventId cannot start a second connect mid-handshake.
    _processedNudgeEventIds.add(action.eventId);
    final index = _groups.indexWhere(
      (group) => group.groupId == action.groupId,
    );
    if (index < 0) {
      setState(() => _message = 'That nudge group is no longer available.');
      return;
    }

    await _onGroupCarouselChanged(index);
    if (!mounted) return;
    _explicitJoinIntent = true;
    try {
      if (!_isViewingActiveGroup) {
        if (_isOnline) {
          await _switchVoiceGroup();
        } else {
          await _goOnline(userIntent: true);
        }
      }
    } on VoicePaywallRequiredException {
      // Trial ended — nudges/chat stay free, but live voice needs Duo Pro.
      // Give sender and receiver different copy for the same event.
      _processedNudgeEventIds.remove(action.eventId);
      _explicitJoinIntent = false;
      if (!mounted) return;
      final isSenderAutoConnect = action.action == 'connect';
      _liveLockedHandledNudgeIds.add(action.eventId);
      unawaited(_nudgeActionBridge.dismissIncomingNudge(action.eventId));
      if (mounted) {
        setState(() {
          _incomingPromptNudge = null;
          _incomingPromptBusy = false;
        });
      }
      if (isSenderAutoConnect) {
        _showPresenceSnackbar(
          'They accepted, but live voice requires Duo Pro.',
        );
      }
      final purchased = await _presentVoicePaywall();
      if (purchased && mounted) {
        _liveLockedHandledNudgeIds.remove(action.eventId);
        await _processNudgeAction(action);
      }
      return;
    }
    if (!mounted) return;
    if (!_isOnline) {
      _processedNudgeEventIds.remove(action.eventId);
      _explicitJoinIntent = false;
      throw StateError('Could not enter the nudge group.');
    }
    // Entered (or is entering) via nudge — remember so a later
    // single-user-in-room bug report can explain how it occurred.
    _enteredViaNudge = true;
    // The receiver accepted the nudge (or this device accepted one) — the
    // last sent nudge is no longer the active pending state.
    NudgeStatusMemory.instance.clear(action.groupId);
    if (mounted) setState(() {});
    if (action.action == 'connect' &&
        _appLifecycle != AppLifecycleState.resumed) {
      // Sender auto-connected while the app stayed in the background — the
      // shade notification is the only confirmation they get.
      final group = _groups
          .where((candidate) => candidate.groupId == action.groupId)
          .firstOrNull;
      unawaited(
        AndroidVoiceNudgeBridge.shared.showYouAreOnlineNotification(
          groupId: action.groupId,
          groupName: group?.name,
        ),
      );
    }
    if (action.action != 'accept') return;
    // 2. Mark accepted, notify sender, accept sibling nudges in the group.
    await _nudgeInbox.mark(
      nudgeId: action.eventId,
      status: ActiveNudgeStatus.accepted,
    );
    unawaited(_nudgeActionBridge.dismissIncomingNudge(action.eventId));
    // Don't block the in-app dialogue on the HTTP respond — the receiver is
    // already live. A hung /respond left Accept spinning forever.
    unawaited(_notifyNudgeAccepted(action));
    debugPrint(
      '[OneOneFCM][DART-07] Accepted nudge and entered group '
      'eventSuffix=${action.eventId.length <= 6 ? action.eventId : action.eventId.substring(action.eventId.length - 6)}',
    );
    _promptRestoreGroupId = null;
    _incomingExpiryTimer?.cancel();
    if (mounted) {
      setState(() {
        _incomingPromptNudge = null;
        _incomingPromptBusy = false;
        _message = 'Nudge accepted — you’re now online together.';
      });
    }
    unawaited(
      _acceptSiblingNudges(action.groupId, exceptNudgeId: action.eventId),
    );
  }

  Future<void> _notifyNudgeAccepted(NudgeNotificationAction action) async {
    try {
      await _nudgeRepository.respond(
        groupId: action.groupId,
        eventId: action.eventId,
        action: 'accept',
      );
    } catch (error) {
      LogManager.log(
        LogLevel.warn,
        'NudgeService',
        'Accept respond failed after join: $error',
        userId: _session.userId,
        groupId: action.groupId,
      );
    }
  }

  /// Sender-side: decline/snooze (and accept) replies update profile signifiers
  /// even when the nudge sheet is closed.
  void _onSenderNudgeResponse(NudgeRecipientResponse response) {
    // Defense in depth: native FCM handling also cancels, but do not leave the
    // 10-min sender expiry armed after any terminal reply (accept/decline/snooze).
    unawaited(_nudgeActionBridge.cancelSenderNudgeExpiry(response.eventId));
    if (response.isAccept) {
      NudgeStatusMemory.instance.clear(response.groupId);
      if (mounted && _selectedGroup?.groupId == response.groupId) {
        setState(() {});
      }
      unawaited(_connectSenderAfterNudgeAccept(response));
      return;
    }

    final updated = NudgeStatusMemory.instance.applyRecipientResponse(
      eventId: response.eventId,
      groupId: response.groupId,
      responderUserId: response.responderUserId ?? '',
      responderName: response.responderName ?? 'Friend',
      action: response.action,
    );
    if (!updated) return;
    if (!mounted) return;
    if (_selectedGroup?.groupId == response.groupId) {
      setState(() {});
    }
  }

  /// Brings the sender online when a receiver accepts, including while the
  /// app is backgrounded (native bridge queues connect + may launch the app).
  Future<void> _connectSenderAfterNudgeAccept(
    NudgeRecipientResponse response,
  ) async {
    if (_nudgeActionInFlight || _goOnlineInFlight || _isOnline) return;
    if (_processedNudgeEventIds.contains(response.eventId)) return;
    final action = NudgeNotificationAction(
      action: 'connect',
      eventId: response.eventId,
      groupId: response.groupId,
    );
    if (_loadingGroups) {
      _deferredNudgeAction = action;
      return;
    }
    try {
      _nudgeActionInFlight = true;
      await _processNudgeAction(action);
    } catch (error) {
      LogManager.log(
        LogLevel.warn,
        'NudgeService',
        'Sender auto-connect after accept failed: $error',
        userId: _session.userId,
        groupId: response.groupId,
      );
    } finally {
      _nudgeActionInFlight = false;
    }
  }

  Map<String, NudgeRecipientReply> _nudgeRepliesForGroup(String? groupId) {
    if (groupId == null || groupId.isEmpty) return const {};
    final entry = NudgeStatusMemory.instance.forGroup(groupId);
    if (entry == null) return const {};
    return {
      for (final signifier in entry.signifiers)
        if (signifier.reply != null) signifier.userId: signifier.reply!,
    };
  }

  /// After the receiver is already live, accept any other still-pending
  /// senders in the same group so both LiveKit tokens connect.
  Future<void> _acceptSiblingNudges(
    String groupId, {
    required String exceptNudgeId,
  }) async {
    await _hydrateIncomingNudges(present: false);
    final extras = _nudgeInbox
        .activeInGroup(groupId)
        .where((nudge) => nudge.nudgeId != exceptNudgeId)
        .toList(growable: false);
    for (final extra in extras) {
      _processedNudgeEventIds.add(extra.nudgeId);
      unawaited(
        _nudgeRepository.respond(
          groupId: extra.groupId,
          eventId: extra.nudgeId,
          action: 'accept',
        ),
      );
      unawaited(_nudgeActionBridge.dismissIncomingNudge(extra.nudgeId));
    }
    await _nudgeInbox.markAllInGroup(
      groupId: groupId,
      status: ActiveNudgeStatus.accepted,
    );
    if (mounted) {
      await _presentIncomingNudgePrompt(ignoreInFlight: true);
    }
  }

  Future<void> _hydrateIncomingNudges({
    String? preferGroupId,
    String? preferNudgeId,
    bool present = true,
  }) async {
    if (_loadingGroups || !mounted) return;
    if (_incomingHydrateInFlight) {
      for (var i = 0; i < 50 && _incomingHydrateInFlight; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 40));
        if (!mounted) return;
      }
      if (present) {
        await _presentIncomingNudgePrompt(
          preferGroupId: preferGroupId,
          preferNudgeId: preferNudgeId,
        );
      }
      return;
    }
    _incomingHydrateInFlight = true;
    try {
      try {
        await _nudgeInbox.bindUser(_session.userId);
      } catch (error) {
        LogManager.log(
          LogLevel.warn,
          'NudgeService',
          'Incoming nudge inbox bind failed: $error',
          userId: _session.userId,
        );
      }
      try {
        final native = await _nudgeActionBridge.listIncomingNudges();
        for (final nudge in native) {
          if (nudge.senderId == _session.userId) continue;
          _nudgeInbox.upsert(nudge);
          if (nudge.status != ActiveNudgeStatus.pending) {
            await _nudgeInbox.mark(
              nudgeId: nudge.nudgeId,
              status: nudge.status,
              snoozedUntil: nudge.snoozedUntil,
            );
          }
        }
      } catch (error) {
        LogManager.log(
          LogLevel.warn,
          'NudgeService',
          'Native incoming nudge cache failed: $error',
          userId: _session.userId,
        );
      }
      try {
        final remote = await _nudgeSync.loadForGroups(
          groupIds: _groups.map((group) => group.groupId),
          currentUserId: _session.userId,
        );
        _nudgeInbox.upsertAll(remote);
      } catch (error) {
        LogManager.log(
          LogLevel.warn,
          'NudgeService',
          'Remote incoming nudge sync failed: $error',
          userId: _session.userId,
        );
      }
    } finally {
      _incomingHydrateInFlight = false;
    }
    if (present && mounted) {
      await _presentIncomingNudgePrompt(
        preferGroupId: preferGroupId,
        preferNudgeId: preferNudgeId,
      );
    }
  }

  Future<void> _presentIncomingNudgePrompt({
    String? preferGroupId,
    String? preferNudgeId,
    bool ignoreInFlight = false,
  }) async {
    if (!mounted ||
        _inPictureInPicture ||
        _loadingGroups ||
        DeviceLogReport.uiBlocking) {
      return;
    }
    if (!ignoreInFlight && (_nudgeActionInFlight || _incomingPromptBusy)) {
      return;
    }
    final queue = _nudgeInbox
        .presentationQueue(
          preferGroupId: preferGroupId ?? _incomingPromptNudge?.groupId,
          preferNudgeId: preferNudgeId,
        )
        .where(
          (nudge) =>
              !_liveLockedHandledNudgeIds.contains(nudge.nudgeId) &&
              _groups.any((group) => group.groupId == nudge.groupId),
        )
        .toList();
    if (queue.isEmpty) {
      await _dismissIncomingPrompt(restoreGroup: _incomingPromptNudge != null);
      return;
    }
    final next = queue.first;
    // Always show accept/decline — never auto-accept from a prior accept in
    // this group (ring/nudge position must stay an explicit choice).
    _promptRestoreGroupId ??= _selectedGroup?.groupId;
    await _focusGroupForIncomingNudge(next);
    if (!mounted) return;
    setState(() => _incomingPromptNudge = next);
    _scheduleIncomingExpiryWatch();
  }

  Future<void> _focusGroupForIncomingNudge(ActiveNudge nudge) async {
    final index = _groups.indexWhere((group) => group.groupId == nudge.groupId);
    if (index < 0) return;
    unawaited(_prefetchLiveKit(group: _groups[index]));
    await _onGroupCarouselChanged(index);
  }

  Future<void> _dismissIncomingPrompt({required bool restoreGroup}) async {
    _incomingExpiryTimer?.cancel();
    final restoreId = _promptRestoreGroupId;
    _promptRestoreGroupId = null;
    if (!mounted) return;
    setState(() {
      _incomingPromptNudge = null;
      _incomingPromptBusy = false;
    });
    if (!restoreGroup || restoreId == null) return;
    final index = _groups.indexWhere((group) => group.groupId == restoreId);
    if (index >= 0) await _onGroupCarouselChanged(index);
  }

  void _scheduleIncomingExpiryWatch() {
    _incomingExpiryTimer?.cancel();
    _incomingExpiryTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      if (!mounted || _incomingPromptNudge == null) {
        _incomingExpiryTimer?.cancel();
        return;
      }
      unawaited(_presentIncomingNudgePrompt());
    });
  }

  Future<void> _acceptIncomingNudge(ActiveNudge nudge) async {
    if (_incomingPromptBusy) return;
    setState(() {
      _incomingPromptBusy = true;
      _incomingPromptNudge = null;
    });
    _incomingExpiryTimer?.cancel();
    try {
      await _processNudgeAction(
        NudgeNotificationAction(
          action: 'accept',
          eventId: nudge.nudgeId,
          groupId: nudge.groupId,
          senderUserId: nudge.senderId,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _incomingPromptBusy = false;
        _incomingPromptNudge = nudge;
        _message = 'Couldn’t join this group. Check your connection.';
      });
      _scheduleIncomingExpiryWatch();
      return;
    } finally {
      if (mounted && _incomingPromptBusy) {
        setState(() => _incomingPromptBusy = false);
      }
    }
    if (mounted) {
      await _presentIncomingNudgePrompt();
    }
  }

  Future<void> _declineIncomingNudge(ActiveNudge nudge) async {
    if (_incomingPromptBusy) return;
    setState(() => _incomingPromptBusy = true);
    // Decline only this event plus any rings that share its shade notification.
    // Do not fan out to every active nudge in the group (that incorrectly
    // declined unrelated voice nudges / other batches when one was declined).
    final batchIds = await _nudgeActionBridge.eventIdsSharingNotification(
      nudge.nudgeId,
    );
    final ids = batchIds.isEmpty ? <String>[nudge.nudgeId] : batchIds;
    for (final eventId in ids) {
      _processedNudgeEventIds.add(eventId);
      unawaited(
        _nudgeRepository.respond(
          groupId: nudge.groupId,
          eventId: eventId,
          action: 'decline',
        ),
      );
      await _nudgeInbox.mark(
        nudgeId: eventId,
        status: ActiveNudgeStatus.declined,
      );
    }
    // One dismiss cancels the shared ring-batch notification (or the single
    // voice slab) and clears native batch state.
    unawaited(_nudgeActionBridge.dismissIncomingNudge(nudge.nudgeId));
    if (!mounted) return;
    setState(() => _incomingPromptBusy = false);
    await _presentIncomingNudgePrompt();
  }
}
