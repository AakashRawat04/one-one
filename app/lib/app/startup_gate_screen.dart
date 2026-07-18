import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/groups/group_entry_resolver.dart';
import '../features/subscriptions/data/subscription_auth_bootstrap.dart';
import '../features/identity/data/identity_repository.dart';
import '../features/identity/models/identity_session.dart';
import '../features/identity/ui/no_groups_screen.dart';
import 'accent_theme.dart';
import 'battery_optimization_screen.dart';
import 'display_name_screen.dart';
import 'profile_picture_screen.dart';
import 'setup_permission_screen.dart';
import 'startup_session_policy.dart';

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
  String? _authError;

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
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;

    _isExistingUser =
        authUser != null &&
        !SubscriptionAuthBootstrap.isPending(prefs, authUser.uid);

    _introTimer = Timer(_introDelay, () async {
      if (!mounted) return;

      final shouldResume = StartupSessionPolicy.shouldResume(
        hadInitialFirebaseUser: _isExistingUser,
        hasCurrentFirebaseUser: FirebaseAuth.instance.currentUser != null,
      );

      if (shouldResume) {
        unawaited(_continueAfterLogin());
      } else {
        setState(() => _showLetsGo = true);
      }
    });
  }

  Future<void> _continueAfterLogin({bool useGoogle = false}) async {
    if (_isLoggingIn) return;

    setState(() {
      _isLoggingIn = true;
      _authError = null;
    });

    try {
      if (useGoogle) await _identityRepository.signInWithGoogle();
      final session = await _identityRepository.ensureIdentity();
      final prefs = await SharedPreferences.getInstance();
      await SubscriptionAuthBootstrap.clear(prefs, session.userId);
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
                        if (!mounted) return;
                        setState(() {
                          _nextScreen = BatteryOptimizationScreen(
                            onComplete: () async {
                              await _markSetupComplete(updatedSession.userId);
                              if (!mounted) return;
                              setState(() {
                                _nextScreen = _GroupEntryBootstrap(
                                  session: updatedSession,
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
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isLoggingIn = false;
        _showLetsGo = true;
        _authError = useGoogle
            ? 'Google sign-in couldn\'t be completed. Check the Firebase Google provider setup and try again.'
            : error.toString();
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
                            onPressed: _isLoggingIn
                                ? null
                                : () => _continueAfterLogin(),
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
                    SizedBox(height: 12.h),
                    AnimatedOpacity(
                      opacity: _showLetsGo ? 1 : 0,
                      duration: _introAnimationDuration,
                      child: SizedBox(
                        width: 260.w,
                        height: 52.h,
                        child: OutlinedButton.icon(
                          onPressed: _isLoggingIn
                              ? null
                              : () => _continueAfterLogin(useGoogle: true),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xff384047),
                            backgroundColor: const Color(0xffF8BE03),
                            side: const BorderSide(
                              color: Color.fromRGBO(56, 64, 71, 0.45),
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(26.r),
                            ),
                          ),
                          icon: Text(
                            'G',
                            style: TextStyle(
                              fontSize: 18.sp,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          label: Text(
                            'Sign in with Google',
                            style: TextStyle(
                              fontSize: 15.sp,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ),
                    ),
                    if (_authError != null) ...[
                      SizedBox(height: 10.h),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 28.w),
                        child: Text(
                          _authError!,
                          textAlign: TextAlign.center,
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: const Color(0xff7a2f2f),
                            fontSize: 11.sp,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
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
                              color: const Color.fromRGBO(56, 64, 71, 0.78),
                              fontSize: 11.sp,
                              height: 1.25,
                            ),
                          ),
                          Text(
                            'terms & policies',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: const Color.fromRGBO(56, 64, 71, 0.78),
                              fontSize: 11.sp,
                              height: 1.25,
                              decoration: TextDecoration.underline,
                              decorationColor: const Color.fromRGBO(
                                56,
                                64,
                                71,
                                0.78,
                              ),
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
        body: Center(child: CircularProgressIndicator(color: Colors.white)),
      );
    }

    return screen;
  }
}
