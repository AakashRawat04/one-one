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
              brightness: Brightness.light,
            ),
            fontFamily: GoogleFonts.poppins().fontFamily,
            textTheme: GoogleFonts.poppinsTextTheme(),
            primaryTextTheme: GoogleFonts.poppinsTextTheme(),
            useMaterial3: true,
          ),
          home: const WithForegroundTask(child: _FirebaseGate()),
        );
      },
    );
  }
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
            backgroundColor: const Color(0xfffe0000),
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
