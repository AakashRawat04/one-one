import 'package:flutter/material.dart';

class FirebaseSetupBlockedScreen extends StatelessWidget {
  const FirebaseSetupBlockedScreen({super.key, required this.errorText});

  final String errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Startup blocked')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: ListView(
            children: [
              Text(
                'The app could not finish Firebase startup.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text(
                'Check that google-services.json matches package '
                'app.oneone.one_one_app, Anonymous Auth is enabled, Realtime '
                'Database exists, database rules are applied, and the phone has '
                'working internet/Google Play services.',
              ),
              const SizedBox(height: 12),
              SelectableText(errorText),
            ],
          ),
        ),
      ),
    );
  }
}
