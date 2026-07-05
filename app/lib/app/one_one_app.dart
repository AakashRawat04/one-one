import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';

import '../features/identity/data/identity_repository.dart';
import '../features/identity/models/identity_session.dart';
import '../features/identity/ui/identity_home_screen.dart';
import 'firebase_setup_blocked_screen.dart';

class OneOneApp extends StatelessWidget {
  const OneOneApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'One One',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xff00c2a8),
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      home: const WithForegroundTask(child: _FirebaseGate()),
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
          return const _BlockingProgressScreen(message: 'Starting app');
        }

        if (snapshot.hasError) {
          return FirebaseSetupBlockedScreen(
            errorText: snapshot.error.toString(),
          );
        }

        return const _IdentityGate();
      },
    );
  }
}

class _IdentityGate extends StatefulWidget {
  const _IdentityGate();

  @override
  State<_IdentityGate> createState() => _IdentityGateState();
}

class _IdentityGateState extends State<_IdentityGate> {
  final IdentityRepository _identityRepository = IdentityRepository();
  late final Future<IdentitySession> _identityFuture = _identityRepository
      .ensureIdentity();

  @override
  void dispose() {
    _identityRepository.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<IdentitySession>(
      future: _identityFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _BlockingProgressScreen(message: 'Signing in');
        }

        if (snapshot.hasError) {
          return FirebaseSetupBlockedScreen(
            errorText: snapshot.error.toString(),
          );
        }

        return IdentityHomeScreen(
          initialSession: snapshot.requireData,
          identityRepository: _identityRepository,
        );
      },
    );
  }
}

class _BlockingProgressScreen extends StatelessWidget {
  const _BlockingProgressScreen({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text(message),
            ],
          ),
        ),
      ),
    );
  }
}
