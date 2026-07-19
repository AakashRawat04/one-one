import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/groups/group_entry_resolver.dart';
import '../features/identity/data/identity_repository.dart';
import '../features/identity/models/identity_session.dart';
import '../features/identity/ui/no_groups_screen.dart';
import 'accent_theme.dart';
import 'display_name_screen.dart';
import 'profile_picture_screen.dart';
import 'setup_permission_screen.dart';

class StartupGateScreen extends StatefulWidget {
  const StartupGateScreen({super.key});

  @override
  State<StartupGateScreen> createState() => _StartupGateScreenState();
}

class _StartupGateScreenState extends State<StartupGateScreen> {
  static const Duration _introDelay = Duration(seconds: 3);

  final IdentityRepository _identityRepository = IdentityRepository();

  bool _isLoggingIn = false;
  Widget? _nextScreen;
  Timer? _introTimer;
  String? _startupError;

  @override
  void initState() {
    super.initState();
    _introTimer = Timer(_introDelay, _continueAfterLogin);
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _identityRepository.dispose();
    super.dispose();
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

      final setupCompleted = await _hasCompletedSetup(session.userId);
      if (!mounted) return;

      if (setupCompleted) {
        setState(() {
          _nextScreen = _GroupEntryBootstrap(
            session: session,
            identityRepository: _identityRepository,
          );
        });
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
                        await _markSetupComplete(readySession.userId);
                        if (!mounted) return;
                        setState(() {
                          _nextScreen = _GroupEntryBootstrap(
                            session: readySession,
                            identityRepository: _identityRepository,
                          );
                        });
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
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;

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
