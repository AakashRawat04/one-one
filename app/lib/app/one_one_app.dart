import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../features/subscriptions/data/remote_config_service.dart';
import '../features/subscriptions/data/revenuecat_service.dart';
import '../features/subscriptions/data/developer_access_service.dart';
import '../features/subscriptions/data/subscription_grace_period_store.dart';
import '../features/subscriptions/data/subscription_auth_bootstrap.dart';
import '../features/subscriptions/models/subscription_state.dart';
import '../features/subscriptions/ui/paywall_screen.dart';
import 'accent_theme.dart';
import 'firebase_setup_blocked_screen.dart';
import 'startup_gate_screen.dart';

class OneOneApp extends StatelessWidget {
  const OneOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: AccentThemeController.accentKey,
      builder: (context, accentKey, _) {
        final seedColor = accentColorForKey(accentKey);

        return MaterialApp(
          title: 'One One',
          debugShowCheckedModeBanner: false,
          builder: (context, child) {
            return ScreenUtilInit(
              designSize: const Size(393, 873),
              minTextAdapt: true,
              splitScreenMode: true,
              child: child,
            );
          },
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: seedColor,
              brightness: Brightness.dark,
            ),
            brightness: Brightness.dark,
            scaffoldBackgroundColor: const Color(0xff101010),
            canvasColor: const Color(0xff101010),
            fontFamily: GoogleFonts.poppins().fontFamily,
            textTheme: GoogleFonts.poppinsTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme,
            ),
            primaryTextTheme: GoogleFonts.poppinsTextTheme(
              ThemeData(brightness: Brightness.dark).textTheme,
            ),
            useMaterial3: true,
          ),
          home: const WithForegroundTask(
            child: _AuthSessionLifecycle(child: _FirebaseGate()),
          ),
        );
      },
    );
  }
}

class _AuthSessionLifecycle extends StatefulWidget {
  const _AuthSessionLifecycle({required this.child});

  final Widget child;

  @override
  State<_AuthSessionLifecycle> createState() => _AuthSessionLifecycleState();
}

class _AuthSessionLifecycleState extends State<_AuthSessionLifecycle>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshFirebaseToken());
    }
  }

  Future<void> _refreshFirebaseToken() async {
    try {
      await FirebaseAuth.instance.currentUser?.getIdToken();
    } catch (_) {
      // Keep the mounted session intact; Firebase retries token refresh on use.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _FirebaseGate extends StatefulWidget {
  const _FirebaseGate();

  @override
  State<_FirebaseGate> createState() => _FirebaseGateState();
}

class _FirebaseGateState extends State<_FirebaseGate> {
  late final Future<FirebaseApp> _firebaseInit = Firebase.initializeApp();

  // Lazy-initialised after Firebase is ready.
  RemoteConfigService? _remoteConfigService;
  RevenueCatService? _revenueCatService;
  Future<SubscriptionState?>? _subscriptionCheckFuture;
  Timer? _graceDeadlineTimer;

  @override
  void dispose() {
    _graceDeadlineTimer?.cancel();
    _revenueCatService?.dispose();
    unawaited(_remoteConfigService?.dispose());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<FirebaseApp>(
      future: _firebaseInit,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return Scaffold(
            backgroundColor: const Color(0xffF8BE03),
            body: SafeArea(
              child: Center(
                child: Image.asset(
                  'assets/logo.png',
                  width: 190.w,
                  fit: BoxFit.contain,
                ),
              ),
            ),
          );
        }

        if (snapshot.hasError) {
          return FirebaseSetupBlockedScreen(
            errorText: snapshot.error.toString(),
          );
        }

        // Firebase is ready — now initialise subscriptions.
        return _subscriptionGate();
      },
    );
  }

  Widget _subscriptionGate() {
    final remoteConfig = _remoteConfigService;
    final revenueCat = _revenueCatService;

    if (remoteConfig == null || revenueCat == null) {
      // Kick off initialisation once.
      _subscriptionCheckFuture ??= _initSubscriptions();
      return FutureBuilder<SubscriptionState?>(
        future: _subscriptionCheckFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return Scaffold(
              backgroundColor: const Color(0xffF8BE03),
              body: SafeArea(
                child: Center(
                  child: Image.asset(
                    'assets/logo.png',
                    width: 190.w,
                    fit: BoxFit.contain,
                  ),
                ),
              ),
            );
          }
          if (snapshot.hasError || snapshot.data == null) {
            // Fall through to the app — don't block on errors.
            return const StartupGateScreen();
          }
          return _buildSubscriptionDecision(snapshot.data!);
        },
      );
    }

    // Services are ready — use the stream for live updates.
    return StreamBuilder<SubscriptionState>(
      stream: revenueCat.subscriptionStateStream,
      initialData: revenueCat.latestState,
      builder: (context, snapshot) {
        final state = snapshot.data;
        if (state == null) return const StartupGateScreen();
        return _buildSubscriptionDecision(state);
      },
    );
  }

  Widget _buildSubscriptionDecision(SubscriptionState state) {
    _scheduleGraceDeadline(state);
    if (state.shouldBlock) {
      return PaywallScreen(
        revenueCatService: _revenueCatService!,
        subscriptionState: state,
      );
    }
    return const StartupGateScreen();
  }

  void _scheduleGraceDeadline(SubscriptionState state) {
    _graceDeadlineTimer?.cancel();
    _graceDeadlineTimer = null;
    if (state.isSubscribed || state.hasDeveloperBypass) return;
    final deadline = state.graceEndsAt;
    if (deadline == null) return;
    final remainingMs = deadline - DateTime.now().millisecondsSinceEpoch;
    if (remainingMs <= 0) return;
    _graceDeadlineTimer = Timer(Duration(milliseconds: remainingMs), () {
      if (mounted) setState(() {});
    });
  }

  Future<SubscriptionState?> _initSubscriptions() async {
    try {
      // 1. Set up Remote Config for tier/grace-period flags.
      final remoteConfig = RemoteConfigService();
      await remoteConfig.initialize();
      _remoteConfigService = remoteConfig;

      // 2. Establish one stable Firebase/RevenueCat identity. Existing users
      // keep their restored UID; new users begin anonymously and may later
      // link that same account to Google during onboarding.
      final auth = FirebaseAuth.instance;
      final prefs = await SharedPreferences.getInstance();
      var user = auth.currentUser;
      if (user == null) {
        user = (await auth.signInAnonymously()).user;
        if (user != null) {
          await SubscriptionAuthBootstrap.markPending(prefs, user.uid);
        }
      }
      if (user == null) {
        throw StateError('Firebase sign-in did not return a user.');
      }

      // 3. Resolve server-verified developer access and grace-period storage.
      final developerAccess = DeveloperAccessService(auth: auth);
      final hasDeveloperBypass = await developerAccess.hasDeveloperBypass();
      final gracePeriodStore = SubscriptionGracePeriodStore(preferences: prefs);

      // 4. Set up RevenueCat with the Firebase UID as its App User ID.
      final revenueCat = RevenueCatService(
        remoteConfigService: remoteConfig,
        appUserId: user.uid,
        developerAccessService: developerAccess,
        gracePeriodStore: gracePeriodStore,
        hasDeveloperBypass: hasDeveloperBypass,
      );
      await revenueCat.initialize();
      _revenueCatService = revenueCat;

      return revenueCat.latestState;
    } catch (e) {
      debugPrint('Subscription init error: $e');
      // Never block the user because of a subscription-check failure.
      return null;
    }
  }
}
