import 'package:flutter/material.dart';

class FirebaseSetupBlockedScreen extends StatelessWidget {
  const FirebaseSetupBlockedScreen({super.key, required this.errorText});

  final String errorText;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Firebase setup needed')),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add Firebase Android config before running this build.',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              const Text('Expected file: android/app/google-services.json'),
              const SizedBox(height: 12),
              SelectableText(errorText),
            ],
          ),
        ),
      ),
    );
  }
}
