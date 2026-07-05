import 'package:flutter/material.dart';

import '../../groups/ui/group_home_screen.dart';
import '../../../phase1_spike/phase1_spike_app.dart';
import '../data/identity_repository.dart';
import '../models/identity_session.dart';

class IdentityHomeScreen extends StatefulWidget {
  const IdentityHomeScreen({
    super.key,
    required this.initialSession,
    required this.identityRepository,
  });

  final IdentitySession initialSession;
  final IdentityRepository identityRepository;

  @override
  State<IdentityHomeScreen> createState() => _IdentityHomeScreenState();
}

class _IdentityHomeScreenState extends State<IdentityHomeScreen> {
  late IdentitySession _session = widget.initialSession;
  late final TextEditingController _displayNameController =
      TextEditingController(text: widget.initialSession.user.displayName);
  bool _saving = false;
  String? _message;

  @override
  void dispose() {
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _saveDisplayName() async {
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final session = await widget.identityRepository.updateDisplayName(
        _displayNameController.text,
      );
      setState(() {
        _session = session;
        _message = 'Saved';
      });
    } catch (error) {
      setState(() {
        _message = error.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _saving = false;
        });
      }
    }
  }

  void _openAudioSpike() {
    Navigator.of(
      context,
    ).push(MaterialPageRoute<void>(builder: (_) => const Phase1SpikeScreen()));
  }

  void _openGroups() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupHomeScreen(session: _session),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('One One'),
        backgroundColor: colors.inversePrimary,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text('Profile', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            TextField(
              controller: _displayNameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _saveDisplayName(),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.icon(
                  onPressed: _saving ? null : _saveDisplayName,
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save'),
                ),
                FilledButton.icon(
                  onPressed: _openGroups,
                  icon: const Icon(Icons.groups_outlined),
                  label: const Text('Groups'),
                ),
                OutlinedButton.icon(
                  onPressed: _openAudioSpike,
                  icon: const Icon(Icons.graphic_eq),
                  label: const Text('Audio spike'),
                ),
              ],
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
            const SizedBox(height: 24),
            _IdentityDetails(session: _session),
          ],
        ),
      ),
    );
  }
}

class _IdentityDetails extends StatelessWidget {
  const _IdentityDetails({required this.session});

  final IdentitySession session;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _DetailRow(label: 'User ID', value: session.userId),
        _DetailRow(label: 'Device ID', value: session.deviceId),
        _DetailRow(label: 'App version', value: session.device.appVersion),
        _DetailRow(
          label: 'FCM',
          value: session.device.fcmToken == null ? 'not available' : 'saved',
        ),
        _DetailRow(
          label: 'Mic permission',
          value: session.device.micPermissionGranted ? 'granted' : 'missing',
        ),
        _DetailRow(
          label: 'Notifications',
          value: session.device.notificationPermissionGranted
              ? 'granted'
              : 'missing',
        ),
        _DetailRow(label: 'Accent', value: session.settings.accentColorKey),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(label, style: Theme.of(context).textTheme.labelLarge),
          ),
          Expanded(child: SelectableText(value)),
        ],
      ),
    );
  }
}
