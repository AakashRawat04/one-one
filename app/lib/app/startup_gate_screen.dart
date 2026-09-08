import 'package:one_one_app/one_one.dart';

class StartupGateScreen extends StatefulWidget {
  const StartupGateScreen({super.key});

  @override
  State<StartupGateScreen> createState() => _StartupGateScreenState();
}

class _StartupGateScreenState extends State<StartupGateScreen>
    with WidgetsBindingObserver {
  final IdentityRepository _identityRepository = IdentityRepository();
  final GroupRepository _groupRepository = GroupRepository();
  final InviteLinkBridge _inviteLinkBridge = InviteLinkBridge();

  bool _isLoggingIn = false;
  bool _inviteJoinInFlight = false;
  Widget? _nextScreen;
  StreamSubscription<void>? _inviteLinkSubscription;
  IdentitySession? _readySession;
  String? _startupError;
  String? _pendingInviteMessage;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _inviteLinkSubscription = InviteLinkBridge.linkSignals.listen((_) {
      unawaited(_handleIncomingInviteLink());
    });
    // Start identity/session resolution the instant this screen mounts —
    // there's no UX benefit to an artificial delay here, and every
    // millisecond saved shows up as faster time-to-home-screen.
    unawaited(_continueAfterLogin());
  }

  @override
  void dispose() {
    _inviteLinkSubscription?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _identityRepository.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_handleIncomingInviteLink());
    }
  }

  Future<void> _continueAfterLogin() async {
    if (_isLoggingIn) return;
    final stopwatch = Stopwatch()..start();

    setState(() {
      _isLoggingIn = true;
      _startupError = null;
    });

    try {
      final session = await _identityRepository.ensureIdentity();
      logStartupMilestone('local identity ready', stopwatch);
      if (!mounted) return;
      _readySession = session;
      unawaited(
        MarketController.syncWithAccount(
          backendMarketIso: session.user.market,
          persistIfAbsent: _identityRepository.persistMarketIfAbsent,
        ),
      );
      unawaited(
        LocaleController.syncWithAccount(session.settings.preferredLocale),
      );

      final isReturningUser = await _identityRepository.hasCompletedSetup();
      logStartupMilestone('setup state resolved', stopwatch);
      if (!mounted) return;

      // Always pre-fetch groups in parallel regardless of setup state.
      final groupsPrefetch = _groupRepository.loadGroupsForUser(session.userId);

      // Start the free-trial clock as soon as identity is ready so the
      // 7-day window covers onboarding as well as home use.
      await FreeTrialAccess.ensureStarted(session.userId);

      if (isReturningUser) {
        // On every launch, verify critical permissions are still granted.
        // Users can revoke them between sessions via system settings.
        if (!await _requiredPermissionsGranted()) {
          if (!mounted) return;
          setState(() {
            _nextScreen = SetupPermissionScreen(
              onComplete: () => _finishReturningSetup(session),
            );
          });
          return;
        }
        await _markSetupComplete(session.userId);
        await _presentHomeOrTrialGate(
          session,
          groupsPrefetch: groupsPrefetch,
          stopwatch: stopwatch,
        );
        return;
      }

      setState(() {
        _nextScreen = SetupPermissionScreen(
          onComplete: () async {
            if (!mounted) return;
            setState(() {
              _nextScreen = ProfilePictureScreen(
                session: session,
                identityRepository: _identityRepository,
                onComplete: (updatedSession) async {
                  if (!mounted) return;
                  setState(() {
                    _nextScreen = DisplayNameScreen(
                      session: updatedSession,
                      identityRepository: _identityRepository,
                      onComplete: () async {
                        final readySession = await _identityRepository
                            .ensureIdentity();
                        _readySession = readySession;
                        await _identityRepository.markSetupComplete();
                        await _markSetupComplete(readySession.userId);
                        if (!mounted) return;
                        await _presentHomeOrTrialGate(readySession);
                      },
                    );
                  });
                },
              );
            });
          },
        );
      });
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'startup_gate_failed',
        ),
      );
      if (!mounted) return;

      setState(() {
        _isLoggingIn = false;
        _startupError = error.toString();
      });
    }
  }

  /// Returns true when all permissions that the app needs to function are
  /// granted.  Microphone is mandatory; notification and battery-optimisation
  /// are strongly recommended but won't block launch — the red dot on the
  /// home screen will still flag them.
  Future<bool> _requiredPermissionsGranted() async {
    // Microphone is non-negotiable for voice sessions.
    return await Permission.microphone.isGranted;
  }

  Future<void> _finishReturningSetup(IdentitySession session) async {
    await _markSetupComplete(session.userId);
    final readySession = await _identityRepository.ensureIdentity();
    _readySession = readySession;
    if (!mounted) return;
    await _presentHomeOrTrialGate(readySession);
  }

  /// Home, nudges and chat are free forever — the free trial only gates
  /// live voice, which is checked inline at the moment of connecting
  /// (`_goOnline` in `identity_home_presence.dart`) so it can show
  /// tailored receiver/sender copy plus the Duo Pro paywall right there.
  ///
  /// This method no longer blocks entry to home after the trial ends; it
  /// is kept (rather than inlined) so call sites and naming stay stable if
  /// a future startup-level check is reintroduced.
  Future<void> _presentHomeOrTrialGate(
    IdentitySession session, {
    Future<List<GroupSummary>>? groupsPrefetch,
    Stopwatch? stopwatch,
    String? preferredGroupId,
  }) async {
    await _presentHomeScreen(
      session,
      groupsPrefetch: groupsPrefetch,
      stopwatch: stopwatch,
      preferredGroupId: preferredGroupId,
    );
  }

  /// Keeps the splash visible while home data is prefetched in parallel with
  /// invite handling, then transitions once the first home frame can render.
  Future<void> _presentHomeScreen(
    IdentitySession session, {
    Future<List<GroupSummary>>? groupsPrefetch,
    Stopwatch? stopwatch,
    String? preferredGroupId,
  }) async {
    final phase = stopwatch ?? (Stopwatch()..start());
    groupsPrefetch ??= _groupRepository.loadGroupsForUser(session.userId);

    late final String? invitedGroupId;
    late final List<GroupSummary> groups;
    if (preferredGroupId != null) {
      invitedGroupId = preferredGroupId;
      groups = await groupsPrefetch;
    } else {
      final results = await Future.wait<Object?>([
        _joinPendingInvite(),
        groupsPrefetch,
      ]);
      invitedGroupId = results[0] as String?;
      groups = results[1]! as List<GroupSummary>;
    }

    // Invite/nudge deep links always win. Otherwise, restore whichever group
    // the user was last active in before the app was killed; if that group
    // no longer exists, IdentityHomeBootstrap.resolveSelectedGroup silently
    // falls back to the first group.
    final preferredForBootstrap =
        invitedGroupId ?? await LastActiveGroupStore.read(session.userId);

    IdentityHomeBootstrap bootstrap;
    try {
      bootstrap = await IdentityHomeBootstrap.fromGroups(
        groupRepository: _groupRepository,
        groups: groups,
        preferredGroupId: preferredForBootstrap,
      );
    } catch (error) {
      bootstrap = IdentityHomeBootstrap.failure(error);
    }

    logStartupMilestone('home prefetch complete', phase);
    if (!mounted) return;

    if (!bootstrap.hasGroups && bootstrap.loadError == null) {
      setState(() {
        _nextScreen = NoGroupsScreen(
          session: session,
          identityRepository: _identityRepository,
        );
      });
    } else {
      setState(() {
        _nextScreen = IdentityHomeScreen(
          initialSession: session,
          identityRepository: _identityRepository,
          initialGroupId: preferredForBootstrap,
          initialBootstrap: bootstrap,
        );
      });
    }
    logStartupMilestone('Home route selected', phase);
    _showPendingInviteMessage();
  }

  Future<bool> _hasCompletedSetup(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_setupCompleteKey(userId)) ?? false;
  }

  Future<void> _markSetupComplete(String userId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_setupCompleteKey(userId), true);
  }

  String _setupCompleteKey(String userId) => 'one_one_setup_complete_$userId';

  Future<void> _handleIncomingInviteLink() async {
    final session = _readySession;
    if (session == null || _nextScreen is IdentityHomeScreen) return;
    if (!await _hasCompletedSetup(session.userId)) return;
    final groupId = await _joinPendingInvite();
    if (!mounted) return;
    if (groupId != null) {
      Navigator.of(context).popUntil((route) => route.isFirst);
      if (!mounted) return;
      await _presentHomeOrTrialGate(
        session,
        groupsPrefetch: _groupRepository.loadGroupsForUser(session.userId),
        preferredGroupId: groupId,
      );
    }
    _showPendingInviteMessage();
  }

  Future<String?> _joinPendingInvite() async {
    if (_inviteJoinInFlight) return null;
    final inviteCode = await _inviteLinkBridge.peekPendingInviteCode();
    if (inviteCode == null) return null;
    _inviteJoinInFlight = true;
    try {
      final groupId = await _groupRepository.joinInvite(inviteCode);
      await _inviteLinkBridge.clearPendingInviteCode(inviteCode);
      debugPrint(
        '[OneOneInvite] Joined pending invite groupSuffix='
        '${groupId.length <= 6 ? groupId : groupId.substring(groupId.length - 6)}',
      );
      _pendingInviteMessage = 'Group joined from invite link.';
      return groupId;
    } catch (error, stack) {
      debugPrint(
        '[OneOneInvite] Pending invite failed ${error.runtimeType}: $error',
      );
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'pending_invite_join_failed',
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
      _pendingInviteMessage = error is ApiException
          ? error.message
          : 'Couldn’t open this invite. Check your connection and try again.';
      return null;
    } finally {
      _inviteJoinInFlight = false;
    }
  }

  void _showPendingInviteMessage() {
    final message = _pendingInviteMessage;
    if (message == null) return;
    _pendingInviteMessage = null;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ScaffoldMessenger.maybeOf(
        context,
      )?.showSnackBar(SnackBar(content: Text(message)));
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextScreen = _nextScreen;
    if (nextScreen != null) {
      // A real destination (permissions/onboarding/home/no-groups) is ready
      // — the native splash can come down now that there's real content
      // behind it, not another loader.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        NativeSplashBridge.markReady();
      });
      return nextScreen;
    }

    if (_startupError != null) {
      // Terminal error state with a retry action — also real, interactive
      // content, so drop the native splash here too.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        NativeSplashBridge.markReady();
      });
      return Scaffold(
        backgroundColor: BrandSplashScreen.backgroundColor,
        body: SafeArea(
          child: Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 28.w),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    context.l10n.startupSetupFailed,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xff7a2f2f),
                      fontSize: 13.sp,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  SizedBox(height: 14.h),
                  OutlinedButton(
                    onPressed: _isLoggingIn ? null : _continueAfterLogin,
                    child: Text(context.l10n.startupTryAgain),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Covered by the native splash. No Flutter logo — that was the
    // duplicate large-logo screen on devices that dismiss the native
    // splash at first frame.
    return const BrandSplashScreen();
  }
}
