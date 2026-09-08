import 'package:one_one_app/one_one.dart';

// Home is split so this file stays the widget + lifecycle shell.
// Logic: home/identity_home_*.dart   UI: home/widgets/*.dart

// Logic clusters (mixins on [_IdentityHomeBase]).
part 'home/identity_home_pip.dart';
part 'home/identity_home_lifecycle.dart';
part 'home/identity_home_groups.dart';
part 'home/identity_home_nudges.dart';
part 'home/identity_home_chat.dart';
part 'home/identity_home_presence.dart';
part 'home/identity_home_livekit.dart';
part 'home/identity_home_navigation.dart';
part 'home/identity_home_derived.dart';

// UI components.
part 'home/widgets/voice_picture_in_picture_view.dart';
part 'home/widgets/home_backdrop.dart';
part 'home/widgets/home_top_chrome.dart';
part 'home/widgets/home_friends_strip.dart';
part 'home/widgets/home_edge_actions.dart';
part 'home/widgets/home_carousel.dart';
part 'home/widgets/home_main_button.dart';
part 'home/widgets/home_setup.dart';

class IdentityHomeScreen extends StatefulWidget {
  const IdentityHomeScreen({
    super.key,
    required this.initialSession,
    required this.identityRepository,
    this.initialGroupId,
    this.initialBootstrap,
  });

  final IdentitySession initialSession;
  final IdentityRepository identityRepository;
  final String? initialGroupId;
  final IdentityHomeBootstrap? initialBootstrap;

  @override
  State<IdentityHomeScreen> createState() => _IdentityHomeScreenState();
}

abstract class _IdentityHomeBase extends State<IdentityHomeScreen>
    with WidgetsBindingObserver, RouteAware {
  final GroupRepository _groupRepository = GroupRepository();
  final OnlineRepository _onlineRepository = OnlineRepository();
  final TalkRepository _talkRepository = TalkRepository();
  final AndroidVoiceNudgeBridge _nudgeActionBridge = AndroidVoiceNudgeBridge();
  final NudgeRepository _nudgeRepository = NudgeRepository();
  final ChatMessageRepository _chatMessageRepository = ChatMessageRepository();
  final InviteLinkBridge _inviteLinkBridge = InviteLinkBridge();
  final VoicePipBridge _voicePipBridge = VoicePipBridge();

  late IdentitySession _session;
  List<GroupSummary> _groups = const [];
  List<GroupMemberSummary> _members = const [];
  Map<String, List<GroupMemberSummary>> _membersByGroupId = {};
  // Groups whose roster we've already fetched (or tried to) purely for the
  // home-screen widget cache — avoids re-fetching every group's members on
  // every _syncDuoWidget() call.
  final Set<String> _widgetMemberFetchAttempted = {};
  // Isolated from _membersByGroupId so widget backfill cannot race home
  // group-loading or change carousel / presence behavior.
  Map<String, List<GroupMemberSummary>> _widgetMembersByGroupId = {};
  Map<String, MemberAvailability> _availability = {};
  Set<String> _speakingUserIds = {};
  List<GroupChatMessage> _chatMessages = const [];
  StreamSubscription<DatabaseEvent>? _chatMessagesSubscription;
  StreamSubscription<Map<String, dynamic>>? _emojiBurstSubscription;

  /// App is assumed foreground at startup; lifecycle callbacks keep it current.
  AppLifecycleState _appLifecycle = AppLifecycleState.resumed;
  GroupSummary? _selectedGroup;
  StreamSubscription<DatabaseEvent>? _availabilitySubscription;
  Timer? _availabilityExpiryTimer;
  bool _hasAvailabilitySnapshot = false;
  StreamSubscription<DatabaseEvent>? _membersSubscription;
  StreamSubscription<DatabaseEvent>? _userGroupsSubscription;
  final List<StreamSubscription<DatabaseEvent>> _memberProfileSubscriptions =
      [];
  Set<String>? _pendingUserGroupIds;
  StreamSubscription<List<ConnectivityResult>>? _connectivitySubscription;
  StreamSubscription<void>? _nudgeActionSubscription;
  StreamSubscription<String>? _nudgeReceivedSubscription;
  StreamSubscription<ActiveNudge>? _incomingNudgeSubscription;
  StreamSubscription<IncomingNudgeStatusUpdate>?
  _incomingNudgeStatusSubscription;
  StreamSubscription<NudgeRecipientResponse>? _nudgeResponseSubscription;
  StreamSubscription<void>? _registrationRenewalSubscription;
  StreamSubscription<void>? _inviteLinkSubscription;
  StreamSubscription<VoicePipAction>? _voicePipActionSubscription;

  OnlineSession? _onlineSession;
  TalkSession? _talkSession;
  Room? _room;
  EventsListener<RoomEvent>? _roomListener;
  SoloParticipantGuard? _soloGuard;
  Timer? _heartbeatTimer;
  List<EmojiBurst> _emojiBursts = const [];

  // True when the current online session was entered by accepting (or
  // connecting to) a nudge. Used to explain *why* a single-user-in-room bug
  // occurred when the solo-participant timeout later fires.
  bool _enteredViaNudge = false;

  // Set only when the user taps Join or accepts/connects a nudge. Room
  // connect is refused without this, so a later foreground cannot resurrect
  // a session the user already left.
  bool _explicitJoinIntent = false;

  // True when a LiveKit session was active at the last backgrounding.
  // Resume may keep that session; it must not start a new one.
  bool _liveSessionActiveOnBackground = false;

  final Set<String> _processedNudgeEventIds = {};

  // Automatic-offline-on-disconnect (with grace period) bookkeeping. See
  // _evaluatePeerPresenceForAutoOffline for the state machine.
  bool _peerWasLiveWithMe = false;
  Timer? _peerDisconnectGraceTimer;

  // Inactivity timeout: if nobody speaks for the configured duration while
  // the room is active, the session auto-closes to prevent runaway costs.
  DateTime? _lastVoiceActivityAt;
  Timer? _inactivityTimer;

  // Daily usage tracker: prevents runaway sessions (e.g. phone left on in a
  // crowd). Accumulates online seconds and caps at 180 min / user / day.
  int _todayOnlineSeconds = 0;
  String? _todayUsageDateKey;
  Timer? _usagePersistTimer; // Flushes accumulated seconds to RTDB every 30 s.

  int _carouselIndex = 0;

  DateTime? _liveKitConnectedAt;

  bool _loadingGroups = true;
  bool _busy = false;

  /// Sync lock so concurrent auto-connect paths (FCM accept + native pending
  /// action) cannot both run [goOnline] and flash live→connecting→live.
  bool _goOnlineInFlight = false;
  bool _audioOutputBusy = false;
  bool _microphoneMutedByUser = false;
  final CallAudioRouteController _callAudio = CallAudioRouteController();
  AudioOutputRoute get _audioRoute => _callAudio.displayRoute;
  bool get _audioMuted => _callAudio.muted;
  StreamSubscription<AudioOutputState>? _audioOutputSubscription;
  StreamSubscription<List<MediaDevice>>? _hardwareAudioDeviceSubscription;
  // Per-user connection style for the *local* user's own connection — never
  // a group-wide mode. Defaults to walkie-talkie (mic off). Tapping the main
  // button latches call mode (mic on, overlapping with peers); tapping again
  // mutes and returns to walkie-talkie. See _toggleConnectionMode.
  String _connectionMode = MemberAvailability.walkieTalkieMode;
  bool _connectionModeBusy = false;
  // Caps continuous call mode at PresenceConfig.callModeTimeout; cancelled
  // whenever the local user leaves call mode (manual toggle, go-away, etc.).
  Timer? _callModeTimeoutTimer;
  bool _voicePaywallOpen = false;
  /// Null until [FreeTrialAccess.snapshot] returns — Join? stays hidden
  /// until we know live voice is allowed.
  bool? _hasLiveVoiceAccess;
  final Set<String> _liveLockedHandledNudgeIds = {};
  String _state = 'away';
  String? _message;
  ConnectionQuality _localConnectionQuality = ConnectionQuality.unknown;
  Map<String, ConnectionQuality> _remoteConnectionQualityByUserId = {};
  List<ConnectivityResult> _connectivity = const [];
  bool _registrationRefreshInFlight = false;
  DateTime? _lastRegistrationRefreshAt;
  NudgeNotificationAction? _deferredNudgeAction;
  bool _nudgeActionInFlight = false;
  final ActiveNudgeInbox _nudgeInbox = ActiveNudgeInbox.instance;
  final ActiveNudgeSync _nudgeSync = ActiveNudgeSync();
  ActiveNudge? _incomingPromptNudge;
  String? _promptRestoreGroupId;
  bool _incomingPromptBusy = false;
  bool _incomingHydrateInFlight = false;
  Timer? _incomingExpiryTimer;
  bool _inviteJoinInFlight = false;
  bool _connectionCleanupInFlight = false;
  String? _lastPeerLossUserId;
  DateTime? _lastPeerLossAt;
  bool _processTeardownInFlight = false;
  StreamSubscription<void>? _processTeardownSubscription;
  late final PeerReconnectCoordinator _peerReconnect;
  bool _inPictureInPicture = false;

  /// True when another route (settings, group action, etc.) covers home.
  bool _routeCovered = false;
  String? _preferredGroupId;

  // Cross-mixin contract — implemented by the clustered mixins below.
  bool get _isOnline;
  bool get _isViewingActiveGroup;
  bool get _isCallMode;
  bool get _isTransmitting;
  bool get _serviceReady;
  bool get _microphoneEnabled;
  List<GroupMemberSummary> get _friends;
  List<GroupMemberSummary> get _displayMembers;
  GroupMemberSummary get _localLiveMember;
  String get _activeLiveGroupName;

  void _showPipOverlayIfLive();
  void _updatePipOverlay();
  void _syncPipSessionState();
  void _syncDuoWidget();
  Future<void> _reportMediaVolume();
  Future<void> _loadGroups();
  Future<void> _endRevokedVoiceSession(String groupId);
  Future<void> _onGroupCarouselChanged(int index);
  Future<void> _takePendingNudgeAction();
  Future<void> _prefetchLiveKit({required GroupSummary group});
  void _listenToChatMessages(String groupId);
  void _listenToEmojiBursts(String groupId);
  Future<void> _clearOpenedChatPiles();
  void _evaluatePeerPresenceForAutoOffline(
    Map<String, MemberAvailability> availability,
  );
  void _recordVoiceActivity();
  void _showPresenceSnackbar(String message);
  void _scheduleAvailabilityExpiryRefresh();
  Future<void> _goOnline({bool userIntent = false});
  Future<void> _switchVoiceGroup();
  Future<bool> _presentVoicePaywall();
  Future<void> _refreshLiveVoiceAccess();
  Future<void> _maybeShowPostTrialPaywall();
  Future<void> _goAway({String reason = 'user_away'});
  Future<void> _toggleConnectionMode();
  Future<void> _connectLiveKit(OnlineSession session, {Room? preparedRoom});
  Future<void> _toggleMicrophone();
  Future<void> _handleConnectionLoss(String message);
  // ignore: unused_element_parameter
  Future<void> _disconnectLiveKit({bool urgent = false});
  void _completeLiveKitSession({required String groupId, String? reason});
  Future<void> _setMicrophoneEnabled(bool enabled);
  Future<void> _runBusy(Future<void> Function() action);
  void _setMessage(String message);
  void _setStateAndMessage(String state, String message);
  void _openNudges();
}

class _IdentityHomeScreenState extends _IdentityHomeBase
    with
        _IdentityHomePip,
        _IdentityHomeLifecycle,
        _IdentityHomeGroups,
        _IdentityHomeNudges,
        _IdentityHomeChat,
        _IdentityHomePresence,
        _IdentityHomeLiveKit,
        _IdentityHomeNavigation,
        _IdentityHomeDerived {
  @override
  void initState() {
    super.initState();
    // 1. Session, lifecycle observer, last-group preference.
    _peerReconnect = PeerReconnectCoordinator(
      onLostConnection: _showPeerLostConnection,
      onBackLive: _showPeerBackLive,
    );
    WidgetsBinding.instance.addObserver(this);
    _session =
        widget.identityRepository.currentSession ?? widget.initialSession;
    unawaited(HomeVisualVariantController.ensureLoaded());
    _preferredGroupId = widget.initialGroupId;
    widget.identityRepository.sessionListenable.addListener(
      _onIdentitySessionChanged,
    );
    // Defer: this screen is first inserted during StartupGateScreen.build,
    // and notifying the root accent ValueListenableBuilder in the same frame
    // fatals with setState-during-build.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AccentThemeController.setAccentKey(_session.settings.accentColorKey);
      unawaited(
        showPostCrashReportDialogIfNeeded(
          context,
          userId: _session.userId,
          groupId: _selectedGroup?.groupId,
        ),
      );
    });
    unawaited(
      AnalyticsService.logScreenView(
        screenName: 'identity_home',
        screenClass: 'IdentityHomeScreen',
      ),
    );
    // 2. Native bridges: nudge, invite, PiP, audio.
    _nudgeActionSubscription = AndroidVoiceNudgeBridge.actionSignals.listen((
      _,
    ) {
      unawaited(_takePendingNudgeAction());
    });
    _nudgeReceivedSubscription = AndroidVoiceNudgeBridge.receivedSignals.listen(
      (groupId) {
        LogManager.log(
          LogLevel.info,
          'NudgeService',
          'FCM trigger received on Dart bridge groupId=$groupId',
          userId: _session.userId,
          groupId: groupId,
        );
        unawaited(_onNudgeReceived(groupId));
      },
    );
    _incomingNudgeSubscription = AndroidVoiceNudgeBridge.incomingSignals.listen(
      (nudge) {
        _nudgeInbox.upsert(nudge);
        if (_appLifecycle == AppLifecycleState.resumed &&
            !_incomingPromptBusy &&
            !DeviceLogReport.uiBlocking) {
          unawaited(_presentIncomingNudgePrompt());
        }
      },
    );
    _incomingNudgeStatusSubscription = AndroidVoiceNudgeBridge
        .incomingStatusSignals
        .listen((update) {
          unawaited(
            _nudgeInbox.mark(
              nudgeId: update.nudgeId,
              status: update.status,
              snoozedUntil: update.snoozedUntil,
            ),
          );
          unawaited(_presentIncomingNudgePrompt());
        });
    _nudgeResponseSubscription = AndroidVoiceNudgeBridge.recipientResponses
        .listen(_onSenderNudgeResponse);
    _registrationRenewalSubscription = AndroidVoiceNudgeBridge
        .registrationSignals
        .listen((_) {
          unawaited(_refreshDeviceRegistration(force: true));
        });
    _inviteLinkSubscription = InviteLinkBridge.linkSignals.listen((_) {
      unawaited(_takePendingInviteLink());
    });
    _voicePipBridge.isInPictureInPicture.addListener(_onPipModeChanged);
    _voicePipActionSubscription = _voicePipBridge.actions.listen(
      (action) => unawaited(_handlePipAction(action)),
    );
    _processTeardownSubscription = _voicePipBridge.processTeardown.listen((_) {
      unawaited(_teardownLiveSessionForProcessDeath());
    });
    _audioOutputSubscription = AudioOutputBridge.changes.listen(
      _handleAudioOutputState,
    );
    unawaited(_refreshAudioOutputState());
    // 3. Connectivity + leftover session from a previous process.
    unawaited(_clearAbandonedOnlineSession());
    unawaited(_startConnectivityMonitoring());
    // 4. Groups: apply startup bootstrap, or load from the network.
    final bootstrap = widget.initialBootstrap;
    if (bootstrap != null) {
      _applyBootstrap(bootstrap);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        logStartupMilestone('Home visible');
        logStartupMilestone('Home data interactive');
        unawaited(_takePendingNudgeAction());
        unawaited(_takePendingInviteLink());
        unawaited(_clearOpenedChatPiles());
        unawaited(_refreshLiveVoiceAccess());
        unawaited(_maybeShowPostTrialPaywall());
      });
    } else {
      unawaited(_loadGroups());
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => logStartupMilestone('Home visible'),
      );
    }
  }

  void _applyBootstrap(IdentityHomeBootstrap bootstrap) {
    _groups = bootstrap.groups;
    _selectedGroup = bootstrap.selectedGroup;
    LogManager.setIdentity(
      userId: _session.userId,
      groupId: bootstrap.selectedGroup?.groupId,
    );
    _members = bootstrap.members;
    // Copy — IdentityHomeBootstrap may hold `const {}`, and later member
    // loads write this map during foreground reconnects.
    _membersByGroupId = Map<String, List<GroupMemberSummary>>.of(
      bootstrap.membersByGroupId,
    );
    _widgetMemberFetchAttempted.clear();
    _carouselIndex = bootstrap.carouselIndex;
    _loadingGroups = false;
    _message = bootstrap.loadError;
    // Defer: this screen is first inserted during StartupGateScreen.build.
    // Syncing the native widget in the same frame blocks the platform
    // thread (bitmap copies) and makes an immediate home-screen nudge
    // look like it failed after FCM already left.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _syncDuoWidget();
    });

    _userGroupsSubscription = _groupRepository
        .userGroupsRef(_session.userId)
        .onValue
        .listen((event) => unawaited(_handleUserGroupsChanged(event)));

    final selected = _selectedGroup;
    if (selected != null) {
      unawaited(AppTelemetry.setActiveGroup(selected.groupId));
      _listenToMembers(selected.groupId);
      _listenToAvailability(selected.groupId);
      _listenToChatMessages(selected.groupId);
      _listenToEmojiBursts(selected.groupId);
      _listenToMemberProfiles(_members);
    }
    unawaited(_reportMediaVolume());
  }

  /// Android-only: pushes the current group roster + last-active group to
  /// the native home-screen widget cache so it can render offline without
  /// waking Flutter. Best-effort — failures are logged, never surfaced.
  @override
  void _syncDuoWidget() {
    if (!Platform.isAndroid) return;
    _publishDuoWidgetSnapshot();
    // The widget can page through every group via its "next" control, but
    // _membersByGroupId here is normally only populated for whichever group
    // is currently focused in-app. Backfill into a widget-only cache so
    // home state is left untouched.
    unawaited(_backfillWidgetMembersAndResync());
  }

  void _publishDuoWidgetSnapshot() {
    unawaited(
      DuoHomeWidgetSync.publish(
        userId: _session.userId,
        apiBaseUrl: AppConfig.apiBaseUrl,
        accentKey: AccentThemeController.accentKey.value,
        lastActiveGroupId: _selectedGroup?.groupId,
        groups: _groups.map((group) {
          final members =
              _membersByGroupId[group.groupId] ??
              _widgetMembersByGroupId[group.groupId] ??
              const [];
          return DuoWidgetGroupSnapshot(
            groupId: group.groupId,
            name: group.name,
            members: members
                .map(
                  (member) => DuoWidgetMemberSnapshot(
                    userId: member.userId,
                    displayName: member.displayName,
                    photoUrl: member.profilePhotoUrl,
                    avatarAsset: member.avatarAsset,
                    online: _availability[member.userId]?.isLive ?? false,
                  ),
                )
                .toList(),
          );
        }).toList(),
      ),
    );
  }

  Future<void> _backfillWidgetMembersAndResync() async {
    final missingGroupIds = _groups
        .map((group) => group.groupId)
        .where(
          (groupId) =>
              !_membersByGroupId.containsKey(groupId) &&
              !_widgetMembersByGroupId.containsKey(groupId) &&
              !_widgetMemberFetchAttempted.contains(groupId),
        )
        .toList();
    if (missingGroupIds.isEmpty) return;
    _widgetMemberFetchAttempted.addAll(missingGroupIds);

    final fetched = await Future.wait(
      missingGroupIds.map((groupId) async {
        try {
          final members = await _groupRepository.loadGroupMembers(groupId);
          return MapEntry(groupId, members);
        } catch (error) {
          debugPrint(
            '[DuoHomeWidgetSync] loadGroupMembers($groupId) failed: $error',
          );
          return null;
        }
      }),
    );
    final resolved = fetched
        .whereType<MapEntry<String, List<GroupMemberSummary>>>();
    if (resolved.isEmpty || !mounted) return;

    _widgetMembersByGroupId = {
      ..._widgetMembersByGroupId,
      for (final entry in resolved) entry.key: entry.value,
    };
    unawaited(
      _precacheGroupMemberPhotos(
        resolved.expand((entry) => entry.value).toList(),
      ),
    );
    _publishDuoWidgetSnapshot();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route != null) {
      appRouteObserver.subscribe(this, route);
    }
  }

  // ── RouteAware callbacks ─────────────────────────────────────────────────

  @override
  void didPush() => _showPipOverlayIfLive();

  @override
  void didPopNext() {
    _routeCovered = false;
    _showPipOverlayIfLive();
  }

  /// Another route was pushed on top of home — show PiP if currently live.
  @override
  void didPushNext() {
    _routeCovered = true;
    _showPipOverlayIfLive();
  }

  @override
  void dispose() {
    // 1. Unhook observers, listeners, timers.
    appRouteObserver.unsubscribe(this);
    LiveSessionOverlayController.instance.clearSession();
    WidgetsBinding.instance.removeObserver(this);
    widget.identityRepository.sessionListenable.removeListener(
      _onIdentitySessionChanged,
    );
    _availabilitySubscription?.cancel();
    _availabilityExpiryTimer?.cancel();
    _membersSubscription?.cancel();
    _chatMessagesSubscription?.cancel();
    _emojiBurstSubscription?.cancel();
    _userGroupsSubscription?.cancel();
    for (final sub in _memberProfileSubscriptions) {
      unawaited(sub.cancel());
    }
    _memberProfileSubscriptions.clear();
    _connectivitySubscription?.cancel();
    _nudgeActionSubscription?.cancel();
    _nudgeReceivedSubscription?.cancel();
    _incomingNudgeSubscription?.cancel();
    _incomingNudgeStatusSubscription?.cancel();
    _nudgeResponseSubscription?.cancel();
    _registrationRenewalSubscription?.cancel();
    _inviteLinkSubscription?.cancel();
    _voicePipActionSubscription?.cancel();
    _processTeardownSubscription?.cancel();
    _audioOutputSubscription?.cancel();
    _hardwareAudioDeviceSubscription?.cancel();
    unawaited(AudioOutputBridge.setProximityMonitoring(false));
    _peerReconnect.clear();
    _voicePipBridge.isInPictureInPicture.removeListener(_onPipModeChanged);
    unawaited(_voicePipBridge.setSessionState(active: false, isTalking: false));
    unawaited(_voicePipBridge.dispose());
    _heartbeatTimer?.cancel();
    _peerDisconnectGraceTimer?.cancel();
    _inactivityTimer?.cancel();
    _callModeTimeoutTimer?.cancel();
    _usagePersistTimer?.cancel();
    _incomingExpiryTimer?.cancel();
    // Persist final usage before disposal.
    // 2. Flush usage, stop talk, drop LiveKit.
    if (_todayOnlineSeconds > 0 && _onlineSession != null) {
      unawaited(_persistDailyUsage(_onlineSession!.groupId));
    }
    final activeTalk = _talkSession;
    if (activeTalk != null) {
      unawaited(_talkRepository.stopTalk(activeTalk, reason: 'screen_closed'));
    }
    unawaited(_disconnectLiveKit());
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _appLifecycle = state;
    if (state == AppLifecycleState.detached) {
      unawaited(_teardownLiveSessionForProcessDeath());
      return;
    }
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      _liveSessionActiveOnBackground = _isOnline && _room != null;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      try {
        unawaited(_refreshDeviceRegistration());
        unawaited(_reportMediaVolume());
        unawaited(_refreshLiveVoiceAccess());
        unawaited(_maybeShowPostTrialPaywall());
        // Notification Accept/Connect taps are queued natively and consumed
        // here. Opening the app by itself must not start a LiveKit session —
        // `_goOnline` still requires `_explicitJoinIntent`.
        unawaited(_takePendingNudgeAction());
        unawaited(_takePendingInviteLink());
        // The user is now actively looking at the app, so any pile that
        // accumulated while backgrounded should be cleared.
        unawaited(_clearOpenedChatPiles());
        if (!_liveSessionActiveOnBackground && !_explicitJoinIntent) {
          LogManager.log(
            LogLevel.info,
            'LiveKitManager',
            'Foreground with no active session and no join intent — '
                'skipping room connect',
            userId: _session.userId,
            groupId: _selectedGroup?.groupId,
          );
        }
      } catch (error) {
        // Resume work must never fatal the root zone (unmodifiable map
        // writes from plugins / inbox prune have historically thrown here).
        LogManager.log(
          LogLevel.error,
          'AppLifecycle',
          'Foreground resume handler failed: $error',
          userId: _session.userId,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentColorForKey(_session.settings.accentColorKey);
    // 1. Compact OS-PiP surface when the window is still collapsing.
    if (_inPictureInPicture || MediaQuery.sizeOf(context).height < 480) {
      final member = _pictureInPictureMember;
      return _VoicePictureInPictureView(
        key: ValueKey(member.userId),
        member: member,
        speaking:
            _speakingUserIds.contains(member.userId) ||
            (_isTransmitting && member.userId == _session.userId),
        talking: _isTransmitting,
        accent: accent,
      );
    }
    final warnings = _setupWarnings();
    final items = _carouselItems;
    final focusedGroup = _selectedGroup;
    final activeGroup = _groups
        .where((group) => group.groupId == _onlineSession?.groupId)
        .firstOrNull;
    final viewingActiveGroup = _isViewingActiveGroup;
    // Local session is the source of truth — remote availability can lag after goAway.
    final live = _isOnline && (_state == 'live' || _state == 'talking');
    final inviteAction = _busy || focusedGroup == null
        ? null
        : () => unawaited(_createInvite());

    // Tri-state for the focused group's control cluster: whether nobody, some,
    // or everybody (self included) is currently online. Drives whether the
    // main button becomes a nudge trigger and whether the nudge bell shows.
    final friends = _friends;
    final anyFriendOnline = friends.any(
      (friend) =>
          (_availability[friend.userId] ?? MemberAvailability.away).isLive,
    );
    final allFriendsOnline =
        friends.isNotEmpty &&
        friends.every(
          (friend) =>
              (_availability[friend.userId] ?? MemberAvailability.away).isLive,
        );
    final groupAllOffline = !live && !anyFriendOnline;
    final groupAllOnline = live && allFriendsOnline;
    final groupMixed = !groupAllOffline && !groupAllOnline;
    final anyMemberOnline = live || anyFriendOnline;
    final showGoLive =
        !_isOnline && anyFriendOnline && _hasLiveVoiceAccess == true;
    final liveVoiceLocked = !_isOnline && _hasLiveVoiceAccess == false;
    final liveAvailability = <String, MemberAvailability>{
      for (final friend in friends)
        friend.userId:
            (_availability[friend.userId] ?? MemberAvailability.away).isLive
            ? MemberAvailability(
                desiredState: 'online',
                effectiveState: _speakingUserIds.contains(friend.userId)
                    ? 'talking'
                    : 'live',
                canReceiveLiveAudio: true,
                connectionMode:
                    _availability[friend.userId]?.connectionMode ??
                    MemberAvailability.walkieTalkieMode,
              )
            : (_availability[friend.userId] ?? MemberAvailability.away),
    };
    // Live nav-bar / home-indicator inset (gesture pill vs 3-button). Uses
    // viewPadding as a fallback because modal routes and Android
    // edge-to-edge often report padding.bottom as 0. Captured here, before
    // the inner SafeArea, so the pinned messages bar / main button row
    // can sit above the system nav without touching the top inset.
    final bottomSystemInset = bottomSystemInsetOf(context);

    // When the chat keyboard is open, temporarily collapse and fade the
    // status-hint notifier and the join/create carousel row so the message
    // feed has more space above the keyboard. The group name + participants
    // strip stays visible.
    final keyboardOpen = MediaQuery.of(context).viewInsets.bottom > 100;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 2. Blurred member collage.
          _HomeBackdrop(
            members: _displayMembers,
            fallbackPhotoUrl: _session.user.profilePhotoUrl,
            fallbackPhotoBase64: _session.user.profilePhotoBase64,
            fallbackAvatarAsset: _session.user.avatarAsset,
            accent: accent,
          ),
          // `bottom: false` here because bottom clearance for the pinned
          // controls at the end of the column is now applied explicitly
          // (see `bottomSystemInset` below) so 3-button-nav devices get
          // real extra space instead of a single fixed gap that assumes a
          // gesture-nav-sized inset.
          SafeArea(
            bottom: false,
            child: Column(
              children: [
                _HomeEdgeVeil(
                  fromTop: true,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 3. Settings, setup, presence, speaker.
                      _TopChrome(
                        onSettings: _openSettings,
                        onSetup: _openSetupWarnings,
                        hasSetupWarnings: warnings.isNotEmpty,
                        busy: _busy,
                        online: live,
                        enabled: _serviceReady,
                        onTogglePresence: _togglePresence,
                        showAudioOutput: _isOnline,
                        speakerOn: _callAudio.speakerOn,
                        audioRoute: _audioRoute,
                        audioMuted: _audioMuted,
                        onToggleAudioOutput: _toggleAudioOutput,
                        onToggleAudioMute: _toggleAudioMute,
                      ),
                      Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(height: 4.h),
                          // 4. Group name + friend chips.
                          _FriendsStrip(
                            groupName: focusedGroup?.name,
                            friends: _friends,
                            availability: liveAvailability,
                            speakingUserIds: _speakingUserIds,
                            connectionQualityByUserId:
                                _remoteConnectionQualityByUserId,
                            nudgeRepliesByUserId: _nudgeRepliesForGroup(
                              focusedGroup?.groupId,
                            ),
                            onInvite: inviteAction,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                if (_isOnline &&
                    (_effectiveLocalConnectionQuality ==
                            ConnectionQuality.poor ||
                        _effectiveLocalConnectionQuality ==
                            ConnectionQuality.lost)) ...[
                  SizedBox(height: 8.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      'Your network connection is a bit low.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: const Color(0xffffb347),
                        fontSize: 12.sp,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                if (_message != null && !(_isOnline && viewingActiveGroup)) ...[
                  SizedBox(height: 10.h),
                  Padding(
                    padding: EdgeInsets.symmetric(horizontal: 24.w),
                    child: Text(
                      UserFacingCopy.sanitize(_message!),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: Colors.white70, fontSize: 12.sp),
                    ),
                  ),
                ],
                // 5. Chat bubble feed (grows upward). The rolling window is
                // only 5 bubbles, so this band is sized to hold them without
                // becoming a scroll view — extra height clips at the top.
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(16.w, 2.h, 16.w, 6.h),
                    child: ClipRect(
                      child: Align(
                        alignment: Alignment.bottomCenter,
                        child: ChatBubbleFeed(
                          messages: _chatMessages,
                          currentUserId: _session.userId,
                          displayNameForUserId: _chatDisplayNameForUser,
                          accent: accent,
                          onExpire: _dismissExpiredChatMessage,
                        ),
                      ),
                    ),
                  ),
                ),
                _HomeEdgeVeil(
                  fromTop: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // 6. Status hint (hidden while the keyboard is open).
                      if (!(_isOnline &&
                          viewingActiveGroup &&
                          !_isSessionConnecting))
                        AnimatedOpacity(
                          duration: const Duration(milliseconds: 180),
                          opacity: keyboardOpen ? 0.0 : 1.0,
                          child: AnimatedAlign(
                            duration: const Duration(milliseconds: 220),
                            curve: Curves.easeOutCubic,
                            alignment: Alignment.topCenter,
                            heightFactor: keyboardOpen ? 0.0 : 1.0,
                            child: Padding(
                              padding: EdgeInsets.fromLTRB(24.w, 0, 24.w, 6.h),
                              child: Text(
                                _isSessionConnecting
                                    ? (_state == 'reconnecting'
                                          ? LiveKitStatus.reconnecting
                                          : LiveKitStatus.connecting)
                                    : viewingActiveGroup
                                    ? (_isTransmitting
                                          ? context.l10n.homeMicOnMute
                                          : context.l10n.homeTapToTalk)
                                    : _isOnline
                                    ? context.l10n.homeConnectedToOtherGroup(
                                        activeGroup?.name ?? '',
                                      )
                                    : liveVoiceLocked
                                    ? context.l10n.homeLiveVoiceLocked
                                    : showGoLive
                                    ? context.l10n.homeSomeoneLive
                                    : !_serviceReady
                                    ? context.l10n.homeInviteFriendVoice
                                    : context.l10n.homeSendNudgeTogether,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: const Color.fromRGBO(
                                    255,
                                    255,
                                    255,
                                    0.55,
                                  ),
                                  fontSize: 13.sp,
                                  fontWeight: FontWeight.w500,
                                  height: 1.3,
                                ),
                              ),
                            ),
                          ),
                        ),
                      // 7. Edge nudge while mixed/live.
                      if ((live && groupMixed) || showGoLive)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            // Flush to the right edge of the safe area.
                            padding: EdgeInsets.only(right: 0, bottom: 6.h),
                            child: _EdgeQuickActions(
                              showNudge: groupMixed || showGoLive,
                              onNudge: _busy ? null : _openNudges,
                            ),
                          ),
                        ),
                      // 8. Group carousel (join / talk / create).
                      AnimatedOpacity(
                        duration: const Duration(milliseconds: 180),
                        opacity: keyboardOpen ? 0.0 : 1.0,
                        child: AnimatedAlign(
                          duration: const Duration(milliseconds: 220),
                          curve: Curves.easeOutCubic,
                          alignment: Alignment.topCenter,
                          heightFactor: keyboardOpen ? 0.0 : 1.0,
                          child: IgnorePointer(
                            ignoring: keyboardOpen,
                            child: SizedBox(
                              height: 160.h,
                              child: _ExperienceCarousel(
                                items: items,
                                index: _carouselIndex,
                                connectedGroupId: _onlineSession?.groupId,
                                connecting: _isSessionConnecting,
                                talkEnabled:
                                    viewingActiveGroup &&
                                    !_busy &&
                                    !_isSessionConnecting,
                                talkActive: _isTransmitting,
                                talkBusy: _connectionModeBusy,
                                accent: accent,
                                nudgeGroupId:
                                    (groupAllOffline ||
                                        liveVoiceLocked ||
                                        (_isOnline && !viewingActiveGroup))
                                    ? focusedGroup?.groupId
                                    : null,
                                goLiveGroupId: showGoLive
                                    ? focusedGroup?.groupId
                                    : null,
                                onNudge: _busy ? null : _openNudges,
                                onSelected: (index) {
                                  unawaited(_onGroupCarouselChanged(index));
                                },
                                onTalkStart: _startTalking,
                                onTalkStop: () => _stopTalking(),
                                onJoinVoiceGroup: _togglePresence,
                                onCreateGroup: _openCreateGroup,
                                onJoinGroup: _openJoinGroup,
                              ),
                            ),
                          ),
                        ),
                      ),
                      if (focusedGroup != null) ...[
                        SizedBox(height: 4.h),
                        // 9. Composer.
                        ChatBubbleBar(
                          key: const ValueKey('home-chat-bubble-bar'),
                          accent: accent,
                          anyMemberOnline: anyMemberOnline,
                          onSend: _sendChatMessage,
                          onEmojiSelected: _triggerEmojiBurst,
                        ),
                      ],
                      // Live system inset + a short base gap so the main
                      // button row sits near the bottom without crowding
                      // the nav area.
                      SizedBox(height: 8.h + bottomSystemInset),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // 10. Emoji bursts + incoming nudge prompt.
          if (_emojiBursts.isNotEmpty)
            EmojiBurstOverlay(
              bursts: _emojiBursts,
              onBurstFinished: _onEmojiBurstFinished,
            ),
          if (_incomingPromptNudge != null)
            IncomingNudgeDialogue(
              item: IncomingNudgePromptItem(
                nudge: _incomingPromptNudge!,
                groupName:
                    _groups
                        .where(
                          (group) =>
                              group.groupId == _incomingPromptNudge!.groupId,
                        )
                        .firstOrNull
                        ?.name ??
                    'Group',
                remainingOtherCount:
                    (_nudgeInbox
                                .presentationQueue()
                                .where(
                                  (nudge) => _groups.any(
                                    (group) => group.groupId == nudge.groupId,
                                  ),
                                )
                                .length -
                            1)
                        .clamp(0, 99),
              ),
              accent: accent,
              busy: _incomingPromptBusy,
              liveVoiceLocked: _hasLiveVoiceAccess == false,
              onAccept: () =>
                  unawaited(_acceptIncomingNudge(_incomingPromptNudge!)),
              onDecline: () =>
                  unawaited(_declineIncomingNudge(_incomingPromptNudge!)),
            ),
        ],
      ),
    );
  }
}
