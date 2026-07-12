import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/accent_theme.dart';
import '../data/identity_repository.dart';
import '../models/identity_session.dart';
import 'profile_avatar.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.identityRepository,
    required this.onSessionChanged,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;
  final ValueChanged<IdentitySession> onSessionChanged;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final TextEditingController _displayNameController =
      TextEditingController(text: widget.session.user.displayName);
  late String _accentColorKey = widget.session.settings.accentColorKey;
  late bool _hapticsEnabled = widget.session.settings.hapticsEnabled;
  late String _audioOutputPreference =
      widget.session.settings.audioOutputPreference;
  late String _persistedAccentColorKey = widget.session.settings.accentColorKey;
  bool _saving = false;
  bool _photoSaving = false;
  bool _hasUnsavedAccentPreview = false;
  String? _message;
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    if (_hasUnsavedAccentPreview) {
      AccentThemeController.setAccentKey(_persistedAccentColorKey);
    }
    _displayNameController.dispose();
    super.dispose();
  }

  Future<void> _changeProfilePhoto() async {
    if (_saving || _photoSaving) return;

    final pickedFile = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 82,
      maxWidth: 1600,
    );
    if (pickedFile == null) return;

    final bytes = await pickedFile.readAsBytes();
    if (!mounted) return;

    setState(() {
      _photoSaving = true;
      _message = null;
    });

    try {
      final session = await widget.identityRepository.updateProfilePhoto(bytes);
      widget.onSessionChanged(session);
      if (!mounted) return;
      setState(() => _message = 'Profile photo updated');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _photoSaving = false);
      }
    }
  }

  Future<void> _save() async {
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      var session = widget.session;
      final displayName = _displayNameController.text.trim();
      if (displayName.isNotEmpty &&
          displayName != widget.session.user.displayName) {
        session = await widget.identityRepository.updateDisplayName(
          displayName,
        );
      }

      session = await widget.identityRepository.updateSettings(
        accentColorKey: _accentColorKey,
        hapticsEnabled: _hapticsEnabled,
        audioOutputPreference: _audioOutputPreference,
      );
      _persistedAccentColorKey = session.settings.accentColorKey;
      _hasUnsavedAccentPreview = false;
      AccentThemeController.setAccentKey(session.settings.accentColorKey);
      widget.onSessionChanged(session);

      if (!mounted) return;
      setState(() => _message = 'Saved');
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Center(
              child: Column(
                children: [
                  Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      ProfileAvatar(
                        profilePhotoUrl: widget.session.user.profilePhotoUrl,
                        profilePhotoBase64:
                            widget.session.user.profilePhotoBase64,
                        radius: 42,
                      ),
                      if (_photoSaving)
                        const Positioned.fill(
                          child: DecoratedBox(
                            decoration: BoxDecoration(
                              color: Color(0x88000000),
                              shape: BoxShape.circle,
                            ),
                            child: Center(
                              child: SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.4,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: _saving || _photoSaving
                        ? null
                        : _changeProfilePhoto,
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Change profile photo'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextField(
              controller: _displayNameController,
              textInputAction: TextInputAction.done,
              decoration: const InputDecoration(
                labelText: 'Display name',
                border: OutlineInputBorder(),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 20),
            Text('Accent color', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final option in accentOptions)
                  ChoiceChip(
                    selected: _accentColorKey == option.key,
                    avatar: CircleAvatar(backgroundColor: option.color),
                    label: Text(option.label),
                    onSelected: _saving
                        ? null
                        : (_) {
                            setState(() {
                              _accentColorKey = option.key;
                              _hasUnsavedAccentPreview =
                                  option.key != _persistedAccentColorKey;
                            });
                            AccentThemeController.setAccentKey(option.key);
                          },
                  ),
              ],
            ),
            const SizedBox(height: 20),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Haptics'),
              subtitle: const Text('Short vibration when talk starts/stops.'),
              value: _hapticsEnabled,
              onChanged: _saving
                  ? null
                  : (value) => setState(() => _hapticsEnabled = value),
            ),
            const SizedBox(height: 12),
            Text('Audio output', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 10),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'speaker',
                  icon: Icon(Icons.volume_up_outlined),
                  label: Text('Speaker'),
                ),
                ButtonSegment(
                  value: 'earpiece',
                  icon: Icon(Icons.phone_in_talk_outlined),
                  label: Text('Phone'),
                ),
              ],
              selected: {_audioOutputPreference},
              onSelectionChanged: _saving
                  ? null
                  : (selection) {
                      setState(() => _audioOutputPreference = selection.first);
                    },
            ),
            const SizedBox(height: 24),
            Text(
              'Background reliability',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            _ChecklistItem(
              ok: widget.session.device.micPermissionGranted,
              label: 'Microphone permission',
              detail: widget.session.device.micPermissionGranted
                  ? 'Ready'
                  : 'Grant mic permission before going live.',
            ),
            _ChecklistItem(
              ok: widget.session.device.notificationPermissionGranted,
              label: 'Foreground notification permission',
              detail: widget.session.device.notificationPermissionGranted
                  ? 'Ready for background service tests'
                  : 'Needed later for reliable background mode.',
            ),
            _ChecklistItem(
              ok: widget.session.device.batteryOptimizationIgnored,
              label: 'Battery optimization',
              detail: widget.session.device.batteryOptimizationIgnored
                  ? 'Ignored'
                  : 'May limit long background sessions.',
            ),
            _ChecklistItem(
              ok: false,
              label: 'Closed-app receive',
              detail:
                  'Not active in this simplified APK. Keep both apps open while testing voice.',
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: colors.onPrimary,
                      ),
                    )
                  : const Icon(Icons.check),
              label: const Text('Save settings'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Text(_message!),
            ],
          ],
        ),
      ),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.ok,
    required this.label,
    required this.detail,
  });

  final bool ok;
  final String label;
  final String detail;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            ok ? Icons.check_circle : Icons.error_outline,
            color: ok ? colors.primary : colors.error,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelLarge),
                const SizedBox(height: 2),
                Text(detail, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
