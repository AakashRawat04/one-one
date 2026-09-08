part of '../identity_home_screen.dart';

// 1. Peer-loss grace, inactivity, daily usage cap.
// 2. Go online / away / switch group.
// 3. Walkie vs call mode and call-mode timeout.

mixin _IdentityHomePresence on _IdentityHomeBase {
  void _showPeerLostConnection(String userId) {
    final now = DateTime.now();
    if (_lastPeerLossUserId == userId &&
        _lastPeerLossAt != null &&
        now.difference(_lastPeerLossAt!) < const Duration(seconds: 3)) {
      return;
    }
    _lastPeerLossUserId = userId;
    _lastPeerLossAt = now;
    final name = _membersByGroupId.values
        .expand((members) => members)
        .where((member) => member.userId == userId)
        .map((member) => member.displayName.trim())
        .firstOrNull;
    _showPresenceSnackbar(
      '${name == null || name.isEmpty ? 'A participant' : name} lost connection.',
    );
  }

  void _showPeerBackLive(String userId) {
    final name = _membersByGroupId.values
        .expand((members) => members)
        .where((member) => member.userId == userId)
        .map((member) => member.displayName.trim())
        .firstOrNull;
    _showPresenceSnackbar(
      '${name == null || name.isEmpty ? 'A participant' : name} is back live.',
    );
  }

  /// Implements "automatic offline handling with a grace period": while
  /// this device is online, watch for the group dropping to exactly one
  /// online member. If nobody else is in (or rejoining) the room for
  /// [PresenceConfig.disconnectGracePeriod], this device is taken offline.
  ///
  /// The countdown only runs while we remain alone uninterrupted. Any other
  /// member rejoining — including still-connecting — cancels/resets it; a
  /// later drop back to one member starts a fresh minute.
  @override
  void _evaluatePeerPresenceForAutoOffline(
    Map<String, MemberAvailability> availability,
  ) {
    if (!_isOnline) {
      _peerWasLiveWithMe = false;
      _peerDisconnectGraceTimer?.cancel();
      _peerDisconnectGraceTimer = null;
      return;
    }

    final anyPeerInSession = _anyOtherMemberInVoiceSession(availability);

    if (anyPeerInSession) {
      _peerWasLiveWithMe = true;
      if (_peerDisconnectGraceTimer != null) {
        _peerDisconnectGraceTimer?.cancel();
        _peerDisconnectGraceTimer = null;
        if (mounted) setState(() => _message = 'Your friend reconnected.');
      }
      return;
    }

    // Never had a peer live with us yet (e.g. we just connected and theirs
    // hasn't propagated) — nothing to react to.
    if (!_peerWasLiveWithMe) return;
    if (_peerDisconnectGraceTimer != null) return;

    _peerDisconnectGraceTimer = Timer(PresenceConfig.disconnectGracePeriod, () {
      _peerDisconnectGraceTimer = null;
      if (!mounted || !_isOnline) return;
      // Re-check at fire time: a rejoin may have landed after the last
      // evaluation (or while this callback was already queued).
      if (_anyOtherMemberInVoiceSession(_availability)) return;
      unawaited(_goAway(reason: 'peer_left'));
      _showPresenceSnackbar(
        'The other participant has gone offline. You are now offline.',
      );
    });
  }

  bool _anyOtherMemberInVoiceSession(
    Map<String, MemberAvailability> availability,
  ) {
    return availability.entries.any(
      (entry) => entry.key != _session.userId && entry.value.isInVoiceSession,
    );
  }

  /// Marks the last time voice activity was detected (local or remote) and
  /// reschedules the inactivity timeout check. Called from talk start/stop
  /// and remote-speaker callbacks so the room stays open as long as anyone
  /// is actually talking.
  @override
  void _recordVoiceActivity() {
    if (!_isOnline) return;
    _lastVoiceActivityAt = DateTime.now();
    _scheduleInactivityCheck();
  }

  /// Starts or resets a timer that auto-closes the room if nobody speaks for
  /// [PresenceConfig.inactivityTimeout]. Prevents runaway sessions when a
  /// phone is left unattended with an open mic.
  void _scheduleInactivityCheck() {
    _inactivityTimer?.cancel();
    if (!_isOnline) return;
    _inactivityTimer = Timer(PresenceConfig.inactivityTimeout, () {
      if (!mounted || !_isOnline) return;
      final lastActivity = _lastVoiceActivityAt;
      if (lastActivity != null &&
          DateTime.now().difference(lastActivity) <
              PresenceConfig.inactivityTimeout) {
        // Activity happened since we scheduled — reschedule instead.
        _scheduleInactivityCheck();
        return;
      }
      unawaited(_goAway(reason: 'inactivity'));
      _showPresenceSnackbar(
        'Room closed due to inactivity. Send a nudge to go online again.',
      );
    });
  }

  /// Returns today's UTC date key (e.g. "2026-07-23") used to partition
  /// daily usage records in RTDB.
  String get _todayDateKey {
    final now = DateTime.now().toUtc();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Loads the accumulated online seconds for this user in the selected
  /// group for today from RTDB. Called once when going online.
  Future<int> _loadDailyUsage(String groupId) async {
    try {
      final snapshot = await AppDatabase.instance()
          .ref('dailyUsage/$groupId/${_session.userId}/$_todayDateKey')
          .get();
      if (snapshot.exists && snapshot.value is Map<Object?, Object?>) {
        final data = snapshot.value! as Map<Object?, Object?>;
        return (data['onlineSeconds'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {
      // Non-fatal — if we can't read usage, assume 0.
    }
    return 0;
  }

  /// Persists the accumulated online seconds to RTDB for today.
  Future<void> _persistDailyUsage(String groupId) async {
    try {
      await AppDatabase.instance()
          .ref('dailyUsage/$groupId/${_session.userId}/$_todayDateKey')
          .update({
            'onlineSeconds': _todayOnlineSeconds,
            'updatedAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
          });
    } catch (_) {
      // Best-effort — usage tracking is not critical for the session itself.
    }
  }

  /// Starts a periodic timer that increments the daily usage counter and
  /// persists it to RTDB every 30 seconds while the user is online.
  void _startUsageTracking() {
    _usagePersistTimer?.cancel();
    // Persist immediately when going online.
    final groupId = _onlineSession?.groupId;
    if (groupId != null) {
      unawaited(_persistDailyUsage(groupId));
    }
    _usagePersistTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (!_isOnline) {
        _usagePersistTimer?.cancel();
        _usagePersistTimer = null;
        return;
      }
      _todayOnlineSeconds += 30;
      final groupId = _onlineSession?.groupId;
      if (groupId != null) {
        unawaited(_persistDailyUsage(groupId));
      }
      // If cap is exceeded mid-session, force offline.
      if (_todayOnlineSeconds >= PresenceConfig.dailyUsageCap.inSeconds) {
        unawaited(_goAway(reason: 'daily_usage_cap'));
        _showPresenceSnackbar(
          'Daily usage limit reached (${PresenceConfig.dailyUsageCap.inMinutes} min). '
          'You can go online again tomorrow.',
        );
      }
    });
  }

  /// Themed Snackbar for presence transitions the user didn't directly
  /// trigger (auto-offline, blocked "go online alone" attempts) — kept
  /// visually consistent with the app's dark glass surfaces rather than
  /// the default Material Snackbar look.
  @override
  void _showPresenceSnackbar(String message) {
    _presentSnackbar((messenger) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xff1e1e1e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            duration: const Duration(seconds: 4),
            content: Row(
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  color: Colors.white70,
                  size: 18.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    message,
                    style: TextStyle(color: Colors.white, fontSize: 13.sp),
                  ),
                ),
              ],
            ),
          ),
        );
    }, debugLabel: 'presence snackbar message=$message');
  }

  /// True when a SnackBar can actually be presented: the widget is mounted,
  /// the app is foregrounded, and a ScaffoldMessenger is in the tree.
  /// Backgrounded Flutter views unregister Scaffolds, so showSnackBar
  /// asserts `_scaffolds.isNotEmpty` even while `mounted` is still true.
  bool get _canPresentSnackbar {
    if (!mounted) return false;
    if (_appLifecycle != AppLifecycleState.resumed) return false;
    if (_inPictureInPicture) return false;
    return ScaffoldMessenger.maybeOf(context) != null;
  }

  void _presentSnackbar(
    void Function(ScaffoldMessengerState messenger) present, {
    required String debugLabel,
  }) {
    if (!_canPresentSnackbar) return;
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      if (messenger == null) return;
      present(messenger);
    } catch (error) {
      debugPrint('[OneOneUI] Could not show $debugLabel: $error');
    }
  }

  @override
  void _scheduleAvailabilityExpiryRefresh() {
    _availabilityExpiryTimer?.cancel();
    final now =
        DateTime.now().millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond;
    final futureExpiries = _availability.values
        .map((item) => item.staleAfterAt)
        .whereType<int>()
        .where((expiry) => expiry > now);
    if (futureExpiries.isEmpty) {
      // Everyone already stale (or no heartbeats) — still re-evaluate so a
      // lone-member grace timer can start without waiting for another RTDB
      // write.
      if (_onlineSession != null) {
        _evaluatePeerPresenceForAutoOffline(_availability);
      }
      return;
    }

    final nextExpiry = futureExpiries.reduce((a, b) => a < b ? a : b);
    _availabilityExpiryTimer = Timer(
      Duration(seconds: nextExpiry - now + 1),
      () {
        if (!mounted) return;
        setState(() {});
        if (_onlineSession != null) {
          _evaluatePeerPresenceForAutoOffline(_availability);
        }
        _scheduleAvailabilityExpiryRefresh();
      },
    );
  }

  void _togglePresence() {
    if (_busy) return;
    if (!_serviceReady) {
      setState(() => _message = 'Invite a friend to enable voice service.');
      return;
    }
    if (_isViewingActiveGroup) {
      unawaited(
        AnalyticsService.logButtonClick(
          buttonName: 'go_away',
          screenName: 'home',
        ),
      );
      _showPresenceSnackbar(
        'You\'re going offline. Tap again when someone is live to rejoin without a nudge.',
      );
      unawaited(_goAway());
      return;
    }
    // Already live in another group — nudge this one instead of auto-switching.
    // Switching voice rooms only happens after an explicit accept/connect.
    if (_isOnline) {
      _openNudges();
      return;
    }
    // If someone else is already online in this group, let the user join
    // directly — no nudge required since the room is already active.
    if (_anyPeerOnline) {
      if (_hasLiveVoiceAccess != true) {
        _showPresenceSnackbar(
          'Live voice requires Duo Pro. Nudges and chat stay free.',
        );
        return;
      }
      unawaited(
        AnalyticsService.logButtonClick(
          buttonName: 'go_live',
          screenName: 'home',
        ),
      );
      unawaited(
        AnalyticsService.logFeatureSelected(
          feature: 'go_live',
          screenName: 'home',
        ),
      );
      unawaited(_goOnlineOrShowPaywall());
      return;
    }
    // Nobody is online yet — the room doesn't exist. Prompt the user to
    // send a nudge so at least two people go online together.
    _showPresenceSnackbar(
      'Send a nudge to go online together — or tap when someone else is already live.',
    );
  }

  /// Wraps a manual [_goOnline] call: swallows [VoicePaywallRequiredException]
  /// (message already set by [_goOnline]) and surfaces the Duo Pro paywall.
  Future<void> _goOnlineOrShowPaywall({bool userIntent = true}) async {
    try {
      await _goOnline(userIntent: userIntent);
    } on VoicePaywallRequiredException {
      await _presentVoicePaywall();
    }
  }

  /// Opens the illustrated gate paywall (nudges/chat remain free).
  /// Single-flight — concurrent callers share one route.
  @override
  Future<bool> _presentVoicePaywall() async {
    if (!mounted || _voicePaywallOpen) return false;
    _voicePaywallOpen = true;
    try {
      final purchased = await DuoGatePaywallScreen.open(
        context,
        mode: DuoGatePaywallMode.voiceBlocked,
      );
      await FreeTrialAccess.markPostTrialPaywallShown(_session.userId);
      await _refreshLiveVoiceAccess();
      return purchased;
    } finally {
      if (mounted) _voicePaywallOpen = false;
    }
  }

  @override
  Future<void> _refreshLiveVoiceAccess() async {
    final snapshot = await FreeTrialAccess.snapshot(userId: _session.userId);
    if (!mounted) return;
    if (_hasLiveVoiceAccess == snapshot.canUseLiveVoice) return;
    setState(() => _hasLiveVoiceAccess = snapshot.canUseLiveVoice);
  }

  /// One-time illustrated paywall when the user returns after trial expiry.
  @override
  Future<void> _maybeShowPostTrialPaywall() async {
    if (!mounted || _voicePaywallOpen || _isOnline) return;
    if (!await FreeTrialAccess.shouldShowPostTrialPaywall(_session.userId)) {
      return;
    }
    if (!mounted) return;
    await _presentVoicePaywall();
  }

  /// True when at least one other group member is actively online.
  bool get _anyPeerOnline {
    return _availability.entries.any(
      (entry) => entry.key != _session.userId && entry.value.isLive,
    );
  }

  @override
  Future<void> _goOnline({bool userIntent = false}) async {
    // 1. Refuse unless the user (or nudge accept) explicitly joined.
    if (!userIntent && !_explicitJoinIntent) {
      LogManager.log(
        LogLevel.warn,
        'LiveKitManager',
        'Blocked room connect without explicit join intent',
        userId: _session.userId,
        groupId: _selectedGroup?.groupId,
      );
      return;
    }

    // 1b. Nudges and chat stay free forever — only live voice needs Duo Pro.
    // Checked here so every entry point (manual toggle, nudge accept, sender
    // auto-connect, group switch) is gated in exactly one place.
    final access = await FreeTrialAccess.resolve(userId: _session.userId);
    if (access == FreeTrialAccessResult.requirePro) {
      _explicitJoinIntent = false;
      throw const VoicePaywallRequiredException();
    }
    // Must be sync (not just `_busy` from a later setState) — accept FCM and
    // native pending-connect can both enter here within the same event loop
    // turn and otherwise each write a new session (live → connecting → live).
    if (_goOnlineInFlight || _busy) {
      LogManager.log(
        LogLevel.info,
        'PresenceRing',
        'goOnline skipped — already in flight '
            '(inFlight=$_goOnlineInFlight busy=$_busy isOnline=$_isOnline)',
        userId: _session.userId,
        groupId: _selectedGroup?.groupId,
      );
      return;
    }
    _explicitJoinIntent = true;
    // Going online resets the nudge-origin marker; the nudge path re-asserts
    // it after a successful connect so manual joins are never mislabeled.
    _enteredViaNudge = false;
    final group = _selectedGroup;
    if (group == null) {
      _explicitJoinIntent = false;
      setState(() => _message = 'Create or join a group first.');
      return;
    }
    if (_isOnline) {
      if (!_isViewingActiveGroup) await _switchVoiceGroup();
      return;
    }
    if (!_serviceReady) {
      _explicitJoinIntent = false;
      setState(() => _message = 'Invite a friend to enable voice service.');
      return;
    }

    _goOnlineInFlight = true;
    setState(() {
      _busy = true;
      _state = 'connecting';
      _message = null;
    });

    // 2. Enforce the daily online-minutes cap.
    final dateKey = _todayDateKey;
    if (_todayUsageDateKey != dateKey) {
      _todayUsageDateKey = dateKey;
      _todayOnlineSeconds = 0;
    }
    final loadedSeconds = await _loadDailyUsage(group.groupId);
    if (loadedSeconds > _todayOnlineSeconds) {
      _todayOnlineSeconds = loadedSeconds;
    }
    if (_todayOnlineSeconds >= PresenceConfig.dailyUsageCap.inSeconds) {
      _explicitJoinIntent = false;
      _goOnlineInFlight = false;
      if (!mounted) return;
      unawaited(
        AnalyticsService.logDailyUsageCapReached(groupId: group.groupId),
      );
      setState(() {
        _busy = false;
        _state = 'away';
        _message =
            'Daily usage limit reached (${PresenceConfig.dailyUsageCap.inMinutes} min). '
            'You can go online again tomorrow.';
      });
      return;
    }

    // 3. Create presence, connect LiveKit (muted), mark live.
    const startingConnectionMode = MemberAvailability.walkieTalkieMode;

    OnlineSession? createdSession;
    // E1: live sessions always warm/connect on speaker regardless of settings.
    const speakerOn = true;
    final preparedToken = LiveKitConnectionWarmer.instance.takeToken(
      group.groupId,
    );
    final preparedRoom = LiveKitConnectionWarmer.instance.takeWarmRoom(
      speakerOn: speakerOn,
    );
    try {
      createdSession = await _onlineRepository.goOnline(
        identity: _session,
        group: group,
        connectionMode: startingConnectionMode,
        preparedToken: preparedToken,
      );
      unawaited(ActiveOnlineSessionStore.save(createdSession));
      await _connectLiveKit(createdSession, preparedRoom: preparedRoom);
      await _onlineRepository.markLive(createdSession);
      _heartbeatTimer?.cancel();
      _heartbeatTimer = Timer.periodic(const Duration(seconds: 10), (_) {
        final activeSession = _onlineSession;
        if (activeSession != null) {
          unawaited(
            _onlineRepository.heartbeat(
              activeSession,
              isTalking: _isTransmitting,
            ),
          );
        }
      });

      if (!mounted) return;
      setState(() {
        _onlineSession = createdSession;
        _connectionMode = startingConnectionMode;
        _microphoneMutedByUser = false;
        _state = 'live';
        _message = LiveKitStatus.live;
      });
      _syncDuoWidget();
      // Ensure remote emoji bursts reattach after going live (bootstrap may
      // have left a dead stream after a prior permission blip).
      _listenToEmojiBursts(group.groupId);
      _syncPipSessionState();
      unawaited(TalkFeedback.joined());
      _cancelCallModeTimeout();
      _scheduleInactivityCheck();
      _startUsageTracking();
      unawaited(
        AnalyticsService.logGoOnline(
          groupId: group.groupId,
          connectionMode: startingConnectionMode,
        ),
      );
      unawaited(
        CrashlyticsService.log(
          'go_online group=${group.groupId} mode=$startingConnectionMode',
        ),
      );
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordNudgeFailure(
          error: error,
          stack: stack,
          failureReason: NudgeFailureReason.livekitSessionFailed,
          receiverId: _session.userId,
          groupId: group.groupId,
          livekitRoomState: _room?.connectionState.toString(),
          extras: {
            'feature': 'presence',
            'connection_mode': startingConnectionMode,
          },
        ),
      );
      // If a warm room was taken but connect never claimed it (e.g. the
      // permission check threw before connect), release it now.
      if (preparedRoom != null && _room != preparedRoom) {
        unawaited(preparedRoom.dispose());
      }
      await _disconnectLiveKit();
      _explicitJoinIntent = false;
      if (createdSession != null) {
        try {
          await _onlineRepository.goAway(createdSession);
        } catch (_) {
          // Best-effort cleanup after a failed connect.
        }
        unawaited(ActiveOnlineSessionStore.clear());
      }
      if (!mounted) return;
      setState(() {
        _state = 'away';
        _message = LiveKitStatus.sanitizeError(error);
      });
    } finally {
      _goOnlineInFlight = false;
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  @override
  Future<void> _switchVoiceGroup() async {
    final previousSession = _onlineSession;
    final nextGroup = _selectedGroup;
    if (previousSession == null || nextGroup == null) return;
    if (previousSession.groupId == nextGroup.groupId) return;

    final previousName = _groups
        .where((group) => group.groupId == previousSession.groupId)
        .map((group) => group.name)
        .firstOrNull;
    await _goAway();
    if (!mounted || _onlineSession != null) return;
    try {
      await _goOnline(userIntent: true);
    } on VoicePaywallRequiredException {
      await _presentVoicePaywall();
      return;
    }
    if (!mounted || _onlineSession?.groupId != nextGroup.groupId) return;
    _showPresenceSnackbar(
      'You joined ${nextGroup.name}. '
      'Connection with ${previousName ?? 'the previous group'} has ended.',
    );
  }

  @override
  Future<void> _goAway({String reason = 'user_away'}) async {
    // 1. Drop join intent and stop talk / timers / LiveKit.
    _explicitJoinIntent = false;
    _deferredNudgeAction = null;
    _liveSessionActiveOnBackground = false;
    final session = _onlineSession;
    if (session == null) {
      setState(() => _state = 'away');
      _syncPipSessionState();
      return;
    }

    setState(() => _state = 'connecting');
    await _runBusy(() async {
      final activeTalk = _talkSession;
      if (activeTalk != null) {
        await _talkRepository.stopTalk(activeTalk, reason: 'going_away');
      }
      _heartbeatTimer?.cancel();
      _heartbeatTimer = null;
      _peerDisconnectGraceTimer?.cancel();
      _peerDisconnectGraceTimer = null;
      _inactivityTimer?.cancel();
      _inactivityTimer = null;
      _lastVoiceActivityAt = null;
      _callModeTimeoutTimer?.cancel();
      _callModeTimeoutTimer = null;
      _usagePersistTimer?.cancel();
      _usagePersistTimer = null;
      // Persist final usage when going away.
      final groupId = session.groupId;
      if (_todayOnlineSeconds > 0) {
        unawaited(_persistDailyUsage(groupId));
      }
      _peerWasLiveWithMe = false;
      _enteredViaNudge = false;
      _completeLiveKitSession(groupId: session.groupId, reason: reason);
      await _disconnectLiveKit();
      // 2. Clear RTDB presence and local session.
      await _onlineRepository.goAway(session, reason: reason);
      unawaited(ActiveOnlineSessionStore.clear());
      unawaited(
        AnalyticsService.logGoAway(groupId: session.groupId, reason: reason),
      );
      unawaited(CrashlyticsService.log('go_away reason=$reason'));
      if (_shouldNotifyGoneOffline(reason)) {
        unawaited(
          _onlineRepository.notifyGoneOffline(session: session, reason: reason),
        );
      }
      if (!mounted) return;
      setState(() {
        _onlineSession = null;
        _talkSession = null;
        _speakingUserIds = const {};
        _state = 'away';
        _connectionMode = MemberAvailability.walkieTalkieMode;
        _message = LiveKitStatus.away;
      });
      _syncDuoWidget();
      _syncPipSessionState();
    });
  }

  /// True for leaves the user did not explicitly request — peer left after a
  /// nudge/elsewhere leave, inactivity, or daily cap. Manual toggle and group
  /// switches stay silent.
  bool _shouldNotifyGoneOffline(String reason) {
    return reason == 'peer_left' ||
        reason == 'inactivity' ||
        reason == 'daily_usage_cap' ||
        reason == 'network_loss';
  }

  /// Latches the local mic on (call mode). Peers can latch independently so
  /// voices overlap; there is no exclusive talk lock.
  Future<void> _startTalking() async {
    if (_isCallMode) return;
    unawaited(
      AnalyticsService.logButtonClick(
        buttonName: 'talk',
        screenName: 'home',
      ),
    );
    await _toggleConnectionMode();
  }

  /// Mutes the local mic. Releases any leftover exclusive talk lock, then
  /// exits call mode so the 15-minute cap is cancelled.
  Future<void> _stopTalking({String reason = 'released'}) async {
    final talkSession = _talkSession;
    if (talkSession != null) {
      setState(() {
        _talkSession = null;
        if (!_isCallMode) {
          _state = 'live';
          _message = LiveKitStatus.live;
        }
      });
      _syncPipSessionState();
      _recordVoiceActivity();

      Object? stopError;
      try {
        if (!_isCallMode) {
          await _setMicrophoneEnabled(false);
          if (mounted) _updatePipOverlay();
        }
      } catch (error) {
        stopError = error;
      }

      try {
        await _talkRepository.stopTalk(talkSession, reason: reason);
        unawaited(
          AnalyticsService.logTalkStop(
            groupId: talkSession.groupId,
            reason: reason,
          ),
        );
      } catch (error) {
        stopError ??= error;
      }

      if (stopError != null && mounted) {
        setState(() => _message = 'Couldn’t stop talking. Try again.');
      }
    }

    if (_isCallMode && reason != 'connection_mode_changed') {
      await _toggleConnectionMode();
    }
  }

  /// Toggles the local user's own connection between walkie-talkie (mic off)
  /// and call (latched-on mic, overlapping with anyone else who has also
  /// tapped). Purely per-user: it never touches anyone else's connection.
  @override
  Future<void> _toggleConnectionMode() async {
    final session = _onlineSession;
    if (session == null || _connectionModeBusy || _busy) {
      return;
    }

    final switchingToCallMode = !_isCallMode;
    final nextMode = switchingToCallMode
        ? MemberAvailability.callMode
        : MemberAvailability.walkieTalkieMode;

    setState(() => _connectionModeBusy = true);
    try {
      // Switching modes mid-press shouldn't leave a dangling talk lock.
      final activeTalk = _talkSession;
      if (activeTalk != null) {
        await _stopTalking(reason: 'connection_mode_changed');
      }

      await _setMicrophoneEnabled(switchingToCallMode);
      await _onlineRepository.setConnectionMode(
        session,
        connectionMode: nextMode,
      );

      if (!mounted) return;
      setState(() {
        _connectionMode = nextMode;
        _microphoneMutedByUser = !switchingToCallMode;
        _state = switchingToCallMode ? 'talking' : 'live';
        _message = switchingToCallMode
            ? LiveKitStatus.talking
            : LiveKitStatus.live;
      });
      if (switchingToCallMode) {
        _scheduleCallModeTimeout();
        unawaited(
          TalkFeedback.talkStarted(
            hapticsEnabled: _session.settings.hapticsEnabled,
          ),
        );
      } else {
        _cancelCallModeTimeout();
        unawaited(
          TalkFeedback.talkStopped(
            hapticsEnabled: _session.settings.hapticsEnabled,
          ),
        );
      }
      _recordVoiceActivity();
      _syncPipSessionState();
      if (mounted) _updatePipOverlay();
      unawaited(
        _onlineRepository.heartbeat(session, isTalking: switchingToCallMode),
      );
      // A mode change (call ↔ walkie-talkie) is a LiveKit state signal; give
      // the solo-participant countdown a fresh start off the latest state.
      _soloGuard?.refreshCountdown();
      unawaited(
        AnalyticsService.logConnectionModeChanged(
          groupId: session.groupId,
          mode: nextMode,
        ),
      );
      if (switchingToCallMode) {
        unawaited(AnalyticsService.logTalkStart(groupId: session.groupId));
      } else {
        unawaited(
          AnalyticsService.logTalkStop(
            groupId: session.groupId,
            reason: 'connection_mode_changed',
          ),
        );
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = 'Couldn\u2019t switch connection mode.');
    } finally {
      if (mounted) setState(() => _connectionModeBusy = false);
    }
  }

  /// Starts (or restarts) the continuous call-mode cap. Fires
  /// [_exitCallModeDueToTimeout] after [PresenceConfig.callModeTimeout].
  void _scheduleCallModeTimeout() {
    _callModeTimeoutTimer?.cancel();
    unawaited(VoiceOverlayBridge.warmup());
    _callModeTimeoutTimer = Timer(PresenceConfig.callModeTimeout, () {
      _callModeTimeoutTimer = null;
      unawaited(_exitCallModeDueToTimeout());
    });
  }

  void _cancelCallModeTimeout() {
    _callModeTimeoutTimer?.cancel();
    _callModeTimeoutTimer = null;
  }

  /// Auto-switches the local user back to walkie-talkie after the continuous
  /// call-mode cap. Keeps them connected to the group — only their mode and
  /// mic change. Other participants are not notified.
  Future<void> _exitCallModeDueToTimeout() async {
    final session = _onlineSession;
    if (session == null || !_isCallMode || _connectionModeBusy) return;

    setState(() => _connectionModeBusy = true);
    try {
      // Concurrent with the mic/mode cutover so the switch is not delayed
      // by TTS. Native side no-ops when media volume is muted.
      unawaited(VoiceOverlayBridge.announceCallModeTimeout());
      await _setMicrophoneEnabled(false);
      await _onlineRepository.setConnectionMode(
        session,
        connectionMode: MemberAvailability.walkieTalkieMode,
      );
      if (!mounted) return;
      setState(() {
        _connectionMode = MemberAvailability.walkieTalkieMode;
        _microphoneMutedByUser = true;
        _state = 'live';
        _message = LiveKitStatus.live;
      });
      _cancelCallModeTimeout();
      _syncPipSessionState();
      if (mounted) _updatePipOverlay();
      unawaited(_onlineRepository.heartbeat(session, isTalking: false));
      // Auto-exiting call mode flips the mic off (a LiveKit state signal).
      // Re-base the solo-participant countdown for any remaining participant.
      _soloGuard?.refreshCountdown();
      _showCallModeTimeoutSnackbar();
    } catch (_) {
      // Best-effort; leave local state as-is if the write fails so the user
      // can still toggle manually.
      if (!mounted) return;
      setState(() => _message = 'Couldn\u2019t leave call mode automatically.');
    } finally {
      if (mounted) setState(() => _connectionModeBusy = false);
    }
  }

  void _showCallModeTimeoutSnackbar() {
    _presentSnackbar((messenger) {
      messenger
        ..clearSnackBars()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xff1e1e1e),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14.r),
              side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
            ),
            margin: EdgeInsets.fromLTRB(16.w, 0, 16.w, 16.h),
            duration: const Duration(seconds: 8),
            content: Row(
              children: [
                Icon(
                  Icons.timer_off_outlined,
                  color: Colors.white70,
                  size: 18.sp,
                ),
                SizedBox(width: 10.w),
                Expanded(
                  child: Text(
                    'Switched back to walkie-talkie after '
                    '${PresenceConfig.callModeTimeout.inMinutes} min in call mode.',
                    style: TextStyle(color: Colors.white, fontSize: 13.sp),
                  ),
                ),
              ],
            ),
            action: SnackBarAction(
              label: context.l10n.homeTalk,
              textColor: const Color(0xfffff1a8),
              onPressed: () {
                if (!_isCallMode) unawaited(_toggleConnectionMode());
              },
            ),
          ),
        );
    }, debugLabel: 'call-mode timeout snackbar');
  }
}
