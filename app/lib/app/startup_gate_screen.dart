import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/groups/group_entry_resolver.dart';
import '../features/groups/data/group_repository.dart';
import '../features/groups/data/invite_link_bridge.dart';
import '../features/identity/data/identity_repository.dart';
import '../features/identity/models/identity_session.dart';
import '../features/identity/ui/identity_home_screen.dart';
import '../features/identity/ui/no_groups_screen.dart';
import '../core/network/api_client.dart';
import 'accent_theme.dart';
import 'display_name_screen.dart';
import 'profile_picture_screen.dart';
import 'setup_permission_screen.dart';

class StartupGateScreen extends StatefulWidget {
  const StartupGateScreen({super.key});

  @override
  State<StartupGateScreen> createState() => _StartupGateScreenState();
}

class _StartupGateScreenState extends State<StartupGateScreen>
    with WidgetsBindingObserver {
  static const Duration _introDelay = Duration(seconds: 3);

  final IdentityRepository _identityRepository = IdentityRepository();
  final GroupRepository _groupRepository = GroupRepository();
  final InviteLinkBridge _inviteLinkBridge = InviteLinkBridge();

  bool _isLoggingIn = false;
  bool _inviteJoinInFlight = false;
  Widget? _nextScreen;
  Timer? _introTimer;
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
    _introTimer = Timer(_introDelay, _continueAfterLogin);
  }

  @override
  void dispose() {
    _introTimer?.cancel();
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

    setState(() {
      _isLoggingIn = true;
      _startupError = null;
    });

    try {
      final session = await _identityRepository.ensureIdentity();
      if (!mounted) return;
      _readySession = session;

      final setupCompleted = await _hasCompletedSetup(session.userId);
      if (!mounted) return;

      if (setupCompleted) {
        final invitedGroupId = await _joinPendingInvite();
        if (!mounted) return;
        setState(() {
          _nextScreen = _GroupEntryBootstrap(
            session: session,
            identityRepository: _identityRepository,
            initialGroupId: invitedGroupId,
          );
        });
        _showPendingInviteMessage();
        return;
      }

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
                  if (!mounted) return;
                  setState(() {
                    _nextScreen = SetupPermissionScreen(
                      onComplete: () async {
                        final readySession = await _identityRepository
                            .ensureIdentity();
                        _readySession = readySession;
                        await _markSetupComplete(readySession.userId);
                        if (!mounted) return;
                        final invitedGroupId = await _joinPendingInvite();
                        if (!mounted) return;
                        setState(() {
                          _nextScreen = _GroupEntryBootstrap(
                            session: readySession,
                            identityRepository: _identityRepository,
                            initialGroupId: invitedGroupId,
                          );
                        });
                        _showPendingInviteMessage();
                      },
                    );
                  });
                },
              );
            });
          },
        );
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoggingIn = false;
        _startupError = error.toString();
      });
    }
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
      setState(() {
        _nextScreen = IdentityHomeScreen(
          initialSession: session,
          identityRepository: _identityRepository,
          initialGroupId: groupId,
        );
      });
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
    } catch (error) {
      debugPrint(
        '[OneOneInvite] Pending invite failed ${error.runtimeType}: $error',
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
      ScaffoldMessenger.maybeOf(context)?.showSnackBar(
        SnackBar(content: Text(message)),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final nextScreen = _nextScreen;
    if (nextScreen != null) {
      return nextScreen;
    }

    return Scaffold(
      backgroundColor: const Color(0xffF8BE03),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 28.w),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/logo.png',
                  width: 190.w,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 28.h),
                if (_startupError == null)
                  SizedBox.square(
                    dimension: 24.w,
                    child: const CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Color(0xff384047),
                    ),
                  )
                else ...[
                  Text(
                    'We couldn\'t finish setting up your account.',
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
                    child: const Text('Try again'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GroupEntryBootstrap extends StatefulWidget {
  const _GroupEntryBootstrap({
    required this.session,
    required this.identityRepository,
    this.initialGroupId,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;
  final String? initialGroupId;

  @override
  State<_GroupEntryBootstrap> createState() => _GroupEntryBootstrapState();
}

class _GroupEntryBootstrapState extends State<_GroupEntryBootstrap> {
  Widget? _screen;

  @override
  void initState() {
    super.initState();
    AccentThemeController.setAccentKey(widget.session.settings.accentColorKey);
    unawaited(_resolveEntryScreen());
  }

  Future<void> _resolveEntryScreen() async {
    try {
      final screen = await resolveGroupEntryScreen(
        session: widget.session,
        identityRepository: widget.identityRepository,
        initialGroupId: widget.initialGroupId,
      );
      if (!mounted) return;
      setState(() => _screen = screen);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _screen = NoGroupsScreen(
          session: widget.session,
          identityRepository: widget.identityRepository,
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = _screen;
    if (screen == null) {
      return const Scaffold(
        backgroundColor: Color(0xff000000),
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return screen;
  }
}
