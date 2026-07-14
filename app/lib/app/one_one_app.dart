import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_screenutil/flutter_screenutil.dart';

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

        return const StartupGateScreen();
      },
    );
  }
}
