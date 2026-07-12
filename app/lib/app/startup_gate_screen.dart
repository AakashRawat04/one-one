import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/groups/group_entry_resolver.dart';
import '../features/identity/data/identity_repository.dart';
import '../features/identity/models/identity_session.dart';
import '../features/identity/ui/no_groups_screen.dart';
import 'accent_theme.dart';
import 'battery_optimization_screen.dart';
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
  static const Duration _introAnimationDuration = Duration(milliseconds: 450);

  final IdentityRepository _identityRepository = IdentityRepository();

  bool _showLetsGo = false;
  bool _isLoggingIn = false;
  bool _isExistingUser = false;
  Widget? _nextScreen;
  Timer? _introTimer;

  @override
  void initState() {
    super.initState();
    unawaited(_prepareIntro());
  }

  @override
  void dispose() {
    _introTimer?.cancel();
    _identityRepository.dispose();
    super.dispose();
  }

  Future<void> _prepareIntro() async {
    final authUser = await FirebaseAuth.instance.authStateChanges().first;
    if (!mounted) return;

    _isExistingUser = authUser != null;

    _introTimer = Timer(_introDelay, () {
      if (!mounted) return;

      if (_isExistingUser) {
        unawaited(_continueAfterLogin());
      } else {
        setState(() => _showLetsGo = true);
      }
    });
  }

  Future<void> _continueAfterLogin() async {
    if (_isLoggingIn) return;

    setState(() => _isLoggingIn = true);

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
          onComplete: () async {
            if (!mounted) return;
            setState(() {
              _nextScreen = DisplayNameScreen(
                session: session,
                identityRepository: _identityRepository,
                onComplete: () async {
                  if (!mounted) return;
                  setState(() {
                    _nextScreen = SetupPermissionScreen(
                      onComplete: () async {
                        if (!mounted) return;
                        setState(() {
                          _nextScreen = BatteryOptimizationScreen(
                            onComplete: () async {
                              await _markSetupComplete(session.userId);
                              if (!mounted) return;
                              setState(() {
                                _nextScreen = _GroupEntryBootstrap(
                                  session: session,
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
          },
        );
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoggingIn = false;
        _showLetsGo = true;
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
      backgroundColor: const Color(0xfffe0000),
      body: SafeArea(
        child: Stack(
          children: [
            Center(
              child: AnimatedSlide(
                offset: _showLetsGo ? Offset(0, -18.h / 100.h) : Offset.zero,
                duration: _introAnimationDuration,
                curve: Curves.easeOutCubic,
                child: Image.asset(
                  'assets/logo.png',
                  width: 190.w,
                  fit: BoxFit.contain,
                ),
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 24.h,
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AnimatedOpacity(
                      opacity: _showLetsGo ? 1 : 0,
                      duration: _introAnimationDuration,
                      child: AnimatedSlide(
                        offset: _showLetsGo
                            ? Offset.zero
                            : const Offset(0, 0.18),
                        duration: _introAnimationDuration,
                        curve: Curves.easeOutCubic,
                        child: SizedBox(
                          width: 260.w,
                          height: 52.h,
                          child: ElevatedButton(
                            onPressed: _isLoggingIn ? null : _continueAfterLogin,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xff384047),
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(26.r),
                              ),
                            ),
                            child: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 200),
                              child: _isLoggingIn
                                  ? SizedBox(
                                      key: const ValueKey('progress'),
                                      width: 20.w,
                                      height: 20.w,
                                      child: const CircularProgressIndicator(
                                        strokeWidth: 2.4,
                                        color: Color(0xff384047),
                                      ),
                                    )
                                  : Text(
                                      'Let\'s go!',
                                      key: const ValueKey('label'),
                                      style: TextStyle(
                                        fontSize: 16.sp,
                                        fontWeight: FontWeight.w600,
                                        color: const Color(0xff384047),
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    SizedBox(height: 30.h),
                    AnimatedOpacity(
                      opacity: _showLetsGo ? 1 : 0,
                      duration: _introAnimationDuration,
                      child: Column(
                        children: [
                          Text(
                            'by continuing you agree to our',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color.fromRGBO(255, 255, 255, 0.78),
                              fontSize: 11.sp,
                              height: 1.25,
                            ),
                          ),
                          Text(
                            'terms & policies',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color.fromRGBO(255, 255, 255, 0.78),
                              fontSize: 11.sp,
                              height: 1.25,
                              decoration: TextDecoration.underline,
                              decorationColor:
                                  const Color.fromRGBO(255, 255, 255, 0.78),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
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
        body: Center(
          child: CircularProgressIndicator(color: Colors.white),
        ),
      );
    }

    return screen;
  }
}