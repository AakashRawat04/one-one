part of '../identity_home_screen.dart';

// 1. Load and select groups; listen to membership index.
// 2. Members + availability for the focused group.
// 3. Carousel selection and invite-link join.

mixin _IdentityHomeGroups on _IdentityHomeBase {
  @override
  Future<void> _loadGroups() async {
    // 1. Fetch groups; empty → no-groups screen.
    final stopwatch = Stopwatch()..start();
    setState(() => _loadingGroups = true);
    try {
      final groups = await _groupRepository.loadGroupsForUser(_session.userId);
      logStartupMilestone('groups loaded', stopwatch);
      if (!mounted) return;
      _userGroupsSubscription ??= _groupRepository
          .userGroupsRef(_session.userId)
          .onValue
          .listen((event) => unawaited(_handleUserGroupsChanged(event)));

      if (groups.isEmpty && (ModalRoute.of(context)?.isCurrent ?? true)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(_replaceWithNoGroups());
        });
        return;
      }

      final selected = IdentityHomeBootstrap.resolveSelectedGroup(
        groups,
        preferredGroupId: _preferredGroupId,
        currentGroup: _selectedGroup,
      );
      final selectedMembers = selected == null
          ? const <GroupMemberSummary>[]
          : await _groupRepository.loadGroupMembers(selected.groupId);
      final membersByGroupId = selected == null
          ? <String, List<GroupMemberSummary>>{}
          : <String, List<GroupMemberSummary>>{
              selected.groupId: selectedMembers,
            };
      logStartupMilestone('selected group members loaded', stopwatch);

      if (!mounted) return;
      setState(() {
        _groups = groups;
        _selectedGroup = selected;
        _membersByGroupId = membersByGroupId;
        // membersByGroupId was just reset to only the selected group —
        // let the widget-sync backfill refetch every group again.
        _widgetMemberFetchAttempted.clear();
        _members = selected == null
            ? const []
            : membersByGroupId[selected.groupId] ?? const [];
        if (selected == null) {
          _availability = {};
          _chatMessages = const [];
        }
      });
      _syncDuoWidget();
      LogManager.setIdentity(groupId: selected?.groupId ?? '');
      if (selected != null) {
        unawaited(AppTelemetry.setActiveGroup(selected.groupId));
        unawaited(
          _precacheGroupMemberPhotos(
            membersByGroupId[selected.groupId] ?? const [],
          ),
        );
        _listenToMemberProfiles(membersByGroupId[selected.groupId] ?? const []);
      } else {
        unawaited(AppTelemetry.setActiveGroup(null));
      }
      _syncCarouselToSelectedGroup();

      // 2. Attach members / availability / chat for the focused group.
      if (selected != null) {
        _listenToMembers(selected.groupId);
        _listenToAvailability(selected.groupId);
        _listenToChatMessages(selected.groupId);
        _listenToEmojiBursts(selected.groupId);
      }
      unawaited(_reportMediaVolume());
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = LiveKitStatus.sanitizeError(error));
    } finally {
      if (mounted && _loadingGroups) {
        setState(() => _loadingGroups = false);
        logStartupMilestone('Home data interactive', stopwatch);
        unawaited(_takePendingNudgeAction());
        unawaited(_takePendingInviteLink());
        unawaited(_clearOpenedChatPiles());
        unawaited(_refreshLiveVoiceAccess());
        unawaited(_maybeShowPostTrialPaywall());
        final pendingGroupIds = _pendingUserGroupIds;
        _pendingUserGroupIds = null;
        if (pendingGroupIds != null) {
          unawaited(_handleIndexedGroupsChanged(pendingGroupIds));
        }
      }
    }
  }

  Future<void> _handleUserGroupsChanged(DatabaseEvent event) async {
    if (!mounted) return;
    final value = event.snapshot.value;
    final indexedGroupIds = value is Map<Object?, Object?>
        ? value.keys.map((key) => key.toString()).toSet()
        : <String>{};
    if (_loadingGroups) {
      _pendingUserGroupIds = indexedGroupIds;
      return;
    }
    await _handleIndexedGroupsChanged(indexedGroupIds);
  }

  Future<void> _handleIndexedGroupsChanged(Set<String> indexedGroupIds) async {
    if (!mounted) return;
    final loadedGroupIds = _groups.map((group) => group.groupId).toSet();
    if (indexedGroupIds.length == loadedGroupIds.length &&
        indexedGroupIds.containsAll(loadedGroupIds)) {
      return;
    }

    final activeGroupId = _onlineSession?.groupId;
    if (activeGroupId != null && !indexedGroupIds.contains(activeGroupId)) {
      await _endRevokedVoiceSession(activeGroupId);
    }
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    if (!mounted) return;
    await _loadGroups();
    if (mounted && indexedGroupIds.isNotEmpty) {
      setState(() => _message = 'Your group membership changed.');
    }
  }

  @override
  Future<void> _endRevokedVoiceSession(String groupId) async {
    if (_onlineSession?.groupId != groupId) return;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
    _peerDisconnectGraceTimer?.cancel();
    _peerDisconnectGraceTimer = null;
    _inactivityTimer?.cancel();
    _inactivityTimer = null;
    _callModeTimeoutTimer?.cancel();
    _callModeTimeoutTimer = null;
    _usagePersistTimer?.cancel();
    _usagePersistTimer = null;
    await _disconnectLiveKit();
    if (!mounted) return;
    setState(() {
      _onlineSession = null;
      _talkSession = null;
      _speakingUserIds = const {};
      _state = 'away';
      _connectionMode = MemberAvailability.walkieTalkieMode;
    });
    _explicitJoinIntent = false;
    _deferredNudgeAction = null;
    _liveSessionActiveOnBackground = false;
    _syncPipSessionState();
  }

  Future<void> _takePendingInviteLink() async {
    if (_inviteJoinInFlight || _loadingGroups) return;
    final inviteCode = await _inviteLinkBridge.peekPendingInviteCode();
    if (inviteCode == null || !mounted) return;
    _inviteJoinInFlight = true;
    try {
      final groupId = await _groupRepository.joinInvite(inviteCode);
      await _inviteLinkBridge.clearPendingInviteCode(inviteCode);
      if (!mounted) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (!mounted) return;
      _preferredGroupId = groupId;
      debugPrint(
        '[OneOneInvite] Joined link while Home was active groupSuffix='
        '${groupId.length <= 6 ? groupId : groupId.substring(groupId.length - 6)}',
      );
      await _loadGroups();
      if (mounted) {
        setState(() => _message = 'Group joined from invite link.');
      }
    } catch (error, stack) {
      debugPrint(
        '[OneOneInvite] Active invite failed ${error.runtimeType}: $error',
      );
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'invite_join_failed',
        ),
      );
      if (error is ApiException &&
          const {
            'invite_not_found',
            'invite_unavailable',
            'group_full',
            'group_not_active',
          }.contains(error.code)) {
        await _inviteLinkBridge.clearPendingInviteCode(inviteCode);
      }
      if (mounted) {
        setState(() {
          _message = error is ApiException
              ? error.message
              : 'Couldn’t open this invite. Check your connection.';
        });
      }
    } finally {
      _inviteJoinInFlight = false;
    }
  }

  Future<void> _replaceWithNoGroups() async {
    await Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => NoGroupsScreen(
          session: _session,
          identityRepository: widget.identityRepository,
        ),
      ),
    );
  }

  Future<void> _loadMembers(String groupId) async {
    final members = await _groupRepository.loadGroupMembers(groupId);
    if (!mounted || _selectedGroup?.groupId != groupId) return;
    setState(() {
      _members = members;
      _membersByGroupId = {..._membersByGroupId, groupId: members};
    });
    _listenToMemberProfiles(members);
  }

  /// Profile photos are loaded with members via RTDB. This just clears any
  /// leftover per-user profile subscriptions from earlier builds.
  void _listenToMemberProfiles(List<GroupMemberSummary> members) {
    for (final sub in _memberProfileSubscriptions) {
      unawaited(sub.cancel());
    }
    _memberProfileSubscriptions.clear();
  }

  Future<void> _precacheGroupMemberPhotos(
    Iterable<GroupMemberSummary> members,
  ) async {
    final urls = members
        .map((member) => member.profilePhotoUrl?.trim())
        .whereType<String>()
        .where((url) => url.isNotEmpty)
        .toSet();

    final dpr = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1.0;
    final pixelSize = (MediaQuery.sizeOf(context).shortestSide * dpr)
        .round()
        .clamp(
          CloudinaryDelivery.minFetchEdge,
          CloudinaryDelivery.maxStoredEdge,
        );
    await Future.wait(
      urls.map((url) async {
        try {
          await precacheImage(
            CachedNetworkImageProvider(
              CloudinaryDelivery.urlFor(url, pixelSize: pixelSize),
            ),
            context,
            onError: (error, stackTrace) {},
          );
        } catch (_) {
          // A broken member photo falls back to initials in ProfileImage.
        }
      }),
    );
  }

  void _listenToMembers(String groupId) {
    unawaited(_membersSubscription?.cancel());
    _membersSubscription = AppDatabase.instance()
        .ref('groupMembers/$groupId')
        .onValue
        .listen((event) {
          if (groupMembershipMatchesSnapshot(
            members: _members,
            snapshotValue: event.snapshot.value,
          )) {
            return;
          }
          unawaited(_loadMembers(groupId));
        });
  }

  void _listenToAvailability(String groupId) {
    unawaited(_availabilitySubscription?.cancel());
    _hasAvailabilitySnapshot = false;
    _availabilitySubscription = AppDatabase.instance()
        .ref('memberAvailability/$groupId')
        .onValue
        .listen((event) {
          final value = event.snapshot.value;
          final next = <String, MemberAvailability>{};

          if (value is Map<Object?, Object?>) {
            for (final entry in value.entries) {
              final raw = entry.value;
              if (raw is Map<Object?, Object?>) {
                next[entry.key.toString()] = MemberAvailability.fromJson(raw);
              }
            }
          }

          if (!mounted || _selectedGroup?.groupId != groupId) return;
          _logFriendRingTransitions(groupId: groupId, next: next, raw: value);
          if (_hasAvailabilitySnapshot) {
            final lostPeerIds = _availability.entries
                .where(
                  (entry) =>
                      entry.key != _session.userId &&
                      entry.value.isLive &&
                      !(next[entry.key]?.isLive ?? false),
                )
                .map((entry) => entry.key)
                .toList(growable: false);
            final rejoinedPeerIds = next.entries
                .where(
                  (entry) =>
                      entry.key != _session.userId &&
                      entry.value.isLive &&
                      !(_availability[entry.key]?.isLive ?? false),
                )
                .map((entry) => entry.key)
                .toList(growable: false);
            for (final userId in lostPeerIds) {
              _peerReconnect.peerLeft(userId);
            }
            for (final userId in rejoinedPeerIds) {
              _peerReconnect.peerJoined(userId);
            }
          }
          setState(() => _availability = next);
          _hasAvailabilitySnapshot = true;
          _scheduleAvailabilityExpiryRefresh();
          if (_onlineSession?.groupId == groupId) {
            _evaluatePeerPresenceForAutoOffline(next);
          }
        });
  }

  /// Logs green-ring (isLive) transitions for friends on the home strip.
  void _logFriendRingTransitions({
    required String groupId,
    required Map<String, MemberAvailability> next,
    required Object? raw,
  }) {
    final rawByUserId = <String, Map<Object?, Object?>>{};
    if (raw is Map<Object?, Object?>) {
      for (final entry in raw.entries) {
        final value = entry.value;
        if (value is Map<Object?, Object?>) {
          rawByUserId[entry.key.toString()] = value;
        }
      }
    }

    for (final friend in _friends) {
      final userId = friend.userId;
      final prevLive =
          (_availability[userId] ?? MemberAvailability.away).isLive;
      final nextAvail = next[userId] ?? MemberAvailability.away;
      final nextLive = nextAvail.isLive;
      if (!_hasAvailabilitySnapshot || prevLive == nextLive) continue;

      final rawEntry = rawByUserId[userId];
      final activeSessionId = rawEntry?['activeServiceSessionId']?.toString();
      final sessionSuffix = activeSessionId == null || activeSessionId.isEmpty
          ? 'none'
          : activeSessionId.length <= 6
          ? activeSessionId
          : activeSessionId.substring(activeSessionId.length - 6);

      LogManager.log(
        LogLevel.info,
        'PresenceRing',
        'UI ring ${prevLive ? "live" : "grey"} -> ${nextLive ? "live" : "grey"} '
            'peer=${friend.displayName} userId=$userId '
            'effective=${nextAvail.effectiveState} desired=${nextAvail.desiredState} '
            'canAudio=${nextAvail.canReceiveLiveAudio} sessionSuffix=$sessionSuffix '
            'localOnline=$_isOnline localState=$_state',
        userId: _session.userId,
        groupId: groupId,
      );
    }
  }

  Future<void> _selectGroup(String groupId) async {
    final group = _groups.firstWhere((item) => item.groupId == groupId);
    final cachedMembers = _membersByGroupId[groupId];
    setState(() {
      _selectedGroup = group;
      _members = cachedMembers ?? const [];
      _availability = {};
      _chatMessages = const [];
    });
    _peerReconnect.clear();
    // Keep native DeviceLog.groupId in sync so FCM can suppress chat piles
    // only for the group currently on screen (not every foreground chat).
    LogManager.setIdentity(groupId: group.groupId);
    unawaited(LastActiveGroupStore.write(_session.userId, group.groupId));
    unawaited(AppTelemetry.setActiveGroup(group.groupId));
    _syncDuoWidget();
    if (cachedMembers == null) {
      await _loadMembers(group.groupId);
    }
    _listenToMembers(group.groupId);
    _listenToAvailability(group.groupId);
    _listenToChatMessages(group.groupId);
    _listenToEmojiBursts(group.groupId);
    _showPipOverlayIfLive();
  }

  @override
  Future<void> _onGroupCarouselChanged(int index) async {
    if (index < 0 || index >= _groups.length) return;
    final group = _groups[index];
    setState(() => _carouselIndex = index);

    if (group.groupId == _selectedGroup?.groupId) return;

    await _selectGroup(group.groupId);
  }

  void _syncCarouselToSelectedGroup() {
    final selected = _selectedGroup;
    if (selected == null || _groups.isEmpty) return;
    final index = _groups.indexWhere(
      (group) => group.groupId == selected.groupId,
    );
    if (index < 0) return;

    _carouselIndex = index;
  }
}
