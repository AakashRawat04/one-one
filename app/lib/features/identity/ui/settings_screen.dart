import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../app/accent_theme.dart';
import '../data/identity_repository.dart';
import '../models/identity_session.dart';
import 'legal_document_screen.dart';
import 'profile_avatar.dart';
import 'profile_photo_editor.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.identityRepository,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;

  /// Opens settings with a dark fade/slide transition (no white flash).
  static Future<void> open(
    BuildContext context, {
    required IdentitySession session,
    required IdentityRepository identityRepository,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: const Color(0xff101010),
        transitionDuration: const Duration(milliseconds: 280),
        reverseTransitionDuration: const Duration(milliseconds: 240),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: ColoredBox(
              color: const Color(0xff101010),
              child: SettingsScreen(
                session: session,
                identityRepository: identityRepository,
              ),
            ),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(
            opacity: curved,
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(curved),
              child: child,
            ),
          );
        },
      ),
    );
  }

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late IdentitySession _session = widget.session;
  late String _accentColorKey = _session.settings.accentColorKey;
  late bool _hapticsEnabled = _session.settings.hapticsEnabled;
  late String _audioOutputPreference = _session.settings.audioOutputPreference;
  late String _persistedAccentColorKey = _session.settings.accentColorKey;
  bool _saving = false;
  bool _photoSaving = false;
  bool _googleSigningIn = false;
  bool _hasUnsavedAccentPreview = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    final currentSession = widget.identityRepository.currentSession;
    if (currentSession != null && currentSession.userId == _session.userId) {
      _session = currentSession;
      _accentColorKey = currentSession.settings.accentColorKey;
      _hapticsEnabled = currentSession.settings.hapticsEnabled;
      _audioOutputPreference = currentSession.settings.audioOutputPreference;
      _persistedAccentColorKey = currentSession.settings.accentColorKey;
    }
    try {
      widget.identityRepository.sessionListenable.addListener(
        _onRepositorySessionChanged,
      );
    } catch (_) {
      // The session listenable may be in a partially-disposed state during
      // navigation transitions. The screen still works with the session
      // captured from the constructor above.
    }
  }

  @override
  void dispose() {
    try {
      widget.identityRepository.sessionListenable.removeListener(
        _onRepositorySessionChanged,
      );
    } catch (_) {
      // Best-effort cleanup when the listenable is already torn down.
    }
    if (_hasUnsavedAccentPreview) {
      AccentThemeController.setAccentKey(_persistedAccentColorKey);
    }
    super.dispose();
  }

  void _onRepositorySessionChanged() {
    final session = widget.identityRepository.currentSession;
    if (!mounted || session == null || session.userId != _session.userId) {
      return;
    }
    setState(() {
      _session = session;
      _hapticsEnabled = session.settings.hapticsEnabled;
      _audioOutputPreference = session.settings.audioOutputPreference;
    });
  }

  void _acceptSession(IdentitySession session) {
    _session = session;
  }

  Future<void> _changeProfilePhoto() async {
    if (_saving || _photoSaving) return;
    try {
      final currentUrl = _session.user.profilePhotoUrl?.trim();
      var recropCurrent = false;
      if (currentUrl != null && currentUrl.isNotEmpty) {
        final choice = await showModalBottomSheet<String>(
          context: context,
          backgroundColor: const Color(0xff1b1b1b),
          showDragHandle: true,
          builder: (context) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose a new photo'),
                  onTap: () => Navigator.pop(context, 'new'),
                ),
                ListTile(
                  leading: const Icon(Icons.crop_outlined),
                  title: const Text('Re-crop current photo'),
                  onTap: () => Navigator.pop(context, 'recrop'),
                ),
              ],
            ),
          ),
        );
        if (choice == null || !mounted) return;
        recropCurrent = choice == 'recrop';
      }
      final bytes = await _openProfilePhotoEditor(
        recropCurrent: recropCurrent,
        currentUrl: currentUrl,
      );
      if (bytes == null || !mounted) return;
      setState(() {
        _photoSaving = true;
        _message = null;
      });
      final session = await widget.identityRepository.updateProfilePhoto(bytes);
      if (!mounted) return;
      setState(() {
        _acceptSession(session);
        _message = 'Profile picture updated';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _photoSaving = false);
    }
  }

  Future<Uint8List?> _openProfilePhotoEditor({
    required bool recropCurrent,
    required String? currentUrl,
  }) {
    if (recropCurrent) {
      return ProfilePhotoEditor.recropNetworkPhoto(context, currentUrl!);
    }
    return ProfilePhotoEditor.pickAndCrop(context);
  }

  Future<void> _openProfileEditor() async {
    final nameController = TextEditingController(
      text: _session.user.displayName,
    );
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xff1b1b1b),
      barrierColor: Colors.black87,
      showDragHandle: true,
      builder: (sheetContext) {
        var nameSaving = false;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            Future<void> saveName() async {
              final displayName = nameController.text.trim();
              if (displayName.isEmpty ||
                  displayName == _session.user.displayName) {
                Navigator.pop(sheetContext);
                return;
              }
              setSheetState(() => nameSaving = true);
              try {
                final session = await widget.identityRepository
                    .updateDisplayName(displayName);
                if (!mounted || !sheetContext.mounted) return;
                setState(() {
                  _acceptSession(session);
                  _message = 'Profile updated';
                });
                Navigator.pop(sheetContext);
              } catch (error) {
                if (!sheetContext.mounted) return;
                setSheetState(() => nameSaving = false);
                ScaffoldMessenger.of(
                  sheetContext,
                ).showSnackBar(SnackBar(content: Text(error.toString())));
              }
            }

            return Padding(
              padding: EdgeInsets.fromLTRB(
                24,
                8,
                24,
                MediaQuery.viewInsetsOf(context).bottom + 28,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Edit profile',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  const Text(
                    'This is how friends see you in your groups.',
                    style: TextStyle(color: Colors.white60),
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: nameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onSubmitted: nameSaving ? null : (_) => saveName(),
                    style: const TextStyle(color: Colors.white),
                    decoration: _darkInputDecoration('Display name'),
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: nameSaving ? null : saveName,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    child: nameSaving
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Save profile'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    nameController.dispose();
  }

  Future<void> _setHapticsEnabled(bool value) async {
    setState(() => _hapticsEnabled = value);
    try {
      final session = await widget.identityRepository.updateSettings(
        accentColorKey: _accentColorKey,
        hapticsEnabled: value,
        audioOutputPreference: _audioOutputPreference,
      );
      _persistedAccentColorKey = session.settings.accentColorKey;
      _hasUnsavedAccentPreview = false;
      if (!mounted) return;
      setState(() => _acceptSession(session));
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _hapticsEnabled = !value;
        _message = 'Couldn’t update haptics setting.';
      });
    }
  }

  Future<void> _setAudioOutputPreference(String value) async {
    final previous = _audioOutputPreference;
    setState(() => _audioOutputPreference = value);
    try {
      final session = await widget.identityRepository.updateSettings(
        accentColorKey: _accentColorKey,
        hapticsEnabled: _hapticsEnabled,
        audioOutputPreference: value,
      );
      if (!mounted) return;
      setState(() => _acceptSession(session));
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _audioOutputPreference = previous;
        _message = 'Couldn\'t update audio output.';
      });
    }
  }

  Future<void> _saveSettings() async {
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final session = await widget.identityRepository.updateSettings(
        accentColorKey: _accentColorKey,
        hapticsEnabled: _hapticsEnabled,
        audioOutputPreference: _audioOutputPreference,
      );
      _persistedAccentColorKey = session.settings.accentColorKey;
      _hasUnsavedAccentPreview = false;
      AccentThemeController.setAccentKey(session.settings.accentColorKey);
      if (!mounted) return;
      setState(() {
        _acceptSession(session);
        _message = 'Settings saved';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _connectGoogleAccount() async {
    if (_googleSigningIn) return;
    setState(() {
      _googleSigningIn = true;
      _message = null;
    });
    try {
      await widget.identityRepository.signInWithGoogle();
      final session = await widget.identityRepository.ensureIdentity();
      if (!mounted) return;
      setState(() {
        _acceptSession(session);
        _message = 'Google account connected';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _googleSigningIn = false);
    }
  }

  void _openLegalDocument(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final accent = accentColorForKey(_accentColorKey);

    return Scaffold(
      backgroundColor: const Color(0xff101010),
      appBar: AppBar(
        backgroundColor: const Color(0xff101010),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: const Text('Settings'),
        centerTitle: true,
      ),
      body: ColoredBox(
        color: const Color(0xff101010),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _ProfileHeader(
                session: _session,
                accent: accent,
                photoSaving: _photoSaving,
                enabled: !_saving && !_photoSaving,
                onChangePhoto: _changeProfilePhoto,
                onEditProfile: _openProfileEditor,
              ),
              const SizedBox(height: 30),
              const _SectionTitle('Preferences'),
              const SizedBox(height: 12),
              _SettingsSurface(
                children: [
                  _PreferenceHeading(
                    icon: Icons.palette_outlined,
                    title: 'Accent color',
                    subtitle: 'Choose the color used across One One.',
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final option in accentOptions)
                        _ColorSwatch(
                          option: option,
                          selected: _accentColorKey == option.key,
                          enabled: !_saving,
                          onSelected: () {
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
                  const _SurfaceDivider(),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    secondary: const Icon(
                      Icons.vibration_outlined,
                      color: Colors.white70,
                    ),
                    title: const Text(
                      'Haptics',
                      style: TextStyle(color: Colors.white),
                    ),
                    subtitle: const Text(
                      'A short vibration when talking starts or stops.',
                      style: TextStyle(color: Colors.white54),
                    ),
                    value: _hapticsEnabled,
                    activeTrackColor: accent,
                    onChanged: _saving
                        ? null
                        : (value) => unawaited(_setHapticsEnabled(value)),
                  ),
                  const _SurfaceDivider(),
                  const _PreferenceHeading(
                    icon: Icons.spatial_audio_off_outlined,
                    title: 'Audio output',
                    subtitle: 'Where incoming voice should play.',
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<String>(
                      style: ButtonStyle(
                        foregroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? Colors.black
                              : Colors.white70,
                        ),
                        backgroundColor: WidgetStateProperty.resolveWith(
                          (states) => states.contains(WidgetState.selected)
                              ? accent
                              : Colors.transparent,
                        ),
                      ),
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
                          : (selection) => unawaited(
                              _setAudioOutputPreference(selection.first),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              if (_session.user.authProvider == 'anonymous') ...[
                const _SectionTitle('Account'),
                const SizedBox(height: 12),
                _SettingsSurface(
                  children: [
                    const _PreferenceHeading(
                      icon: Icons.account_circle_outlined,
                      title: 'Google account',
                      subtitle:
                          'Keep your One One identity with Google sign-in.',
                    ),
                    const SizedBox(height: 16),
                    OutlinedButton.icon(
                      onPressed: _googleSigningIn
                          ? null
                          : _connectGoogleAccount,
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(50),
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      icon: _googleSigningIn
                          ? const SizedBox.square(
                              dimension: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'G',
                              style: TextStyle(fontWeight: FontWeight.w800),
                            ),
                      label: const Text('Sign in with Google'),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
              const _SectionTitle('Background reliability'),
              const SizedBox(height: 12),
              _SettingsSurface(
                children: [
                  _ChecklistItem(
                    ok: _session.device.micPermissionGranted,
                    label: 'Microphone permission',
                    detail: _session.device.micPermissionGranted
                        ? 'Ready'
                        : 'Required before you can talk.',
                  ),
                  _ChecklistItem(
                    ok: _session.device.notificationPermissionGranted,
                    label: 'Notification permission',
                    detail: _session.device.notificationPermissionGranted
                        ? 'Ready for background activity'
                        : 'Required for reliable background activity.',
                  ),
                  _ChecklistItem(
                    ok: _session.device.batteryOptimizationIgnored,
                    label: 'Battery optimization',
                    detail: _session.device.batteryOptimizationIgnored
                        ? 'Unrestricted'
                        : 'Your device may interrupt long sessions.',
                  ),
                  const _ChecklistItem(
                    ok: false,
                    label: 'Closed-app receive',
                    detail: 'Keep One One open while testing voice.',
                    showDivider: false,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              const _SectionTitle('Legal'),
              const SizedBox(height: 12),
              _SettingsSurface(
                padding: EdgeInsets.zero,
                children: [
                  _NavigationRow(
                    icon: Icons.description_outlined,
                    label: 'Terms & Conditions',
                    onTap: () => _openLegalDocument(LegalDocument.terms),
                  ),
                  const _SurfaceDivider(indent: 52),
                  _NavigationRow(
                    icon: Icons.privacy_tip_outlined,
                    label: 'Privacy Policy',
                    onTap: () => _openLegalDocument(LegalDocument.privacy),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: _saving ? null : _saveSettings,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  backgroundColor: accent,
                  foregroundColor: Colors.black,
                ),
                icon: _saving
                    ? const SizedBox.square(
                        dimension: 19,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Save settings'),
              ),
              if (_message != null) ...[
                const SizedBox(height: 14),
                Text(
                  _message!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white70),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

InputDecoration _darkInputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    labelStyle: const TextStyle(color: Colors.white60),
    filled: true,
    fillColor: Colors.white.withValues(alpha: 0.06),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white24),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: const BorderSide(color: Colors.white70),
    ),
  );
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.session,
    required this.accent,
    required this.photoSaving,
    required this.enabled,
    required this.onChangePhoto,
    required this.onEditProfile,
  });

  final IdentitySession session;
  final Color accent;
  final bool photoSaving;
  final bool enabled;
  final VoidCallback onChangePhoto;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: accent, width: 2),
              ),
              child: ProfileAvatar(
                profilePhotoUrl: session.user.profilePhotoUrl,
                profilePhotoBase64: session.user.profilePhotoBase64,
                radius: 48,
                backgroundColor: const Color(0xff2b2b2b),
                fallback: const Icon(
                  Icons.person_outline,
                  color: Colors.white54,
                  size: 42,
                ),
              ),
            ),
            Material(
              color: accent,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: 'Change profile picture',
                onPressed: enabled ? onChangePhoto : null,
                icon: photoSaving
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.black,
                        ),
                      )
                    : const Icon(Icons.camera_alt_outlined),
                color: Colors.black,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        Text(
          session.user.displayName,
          maxLines: 2,
          textAlign: TextAlign.center,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        TextButton.icon(
          onPressed: enabled ? onEditProfile : null,
          icon: const Icon(Icons.edit_outlined, size: 18),
          label: const Text('Edit profile'),
          style: TextButton.styleFrom(foregroundColor: accent),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label.toUpperCase(),
      style: const TextStyle(
        color: Colors.white54,
        fontSize: 12,
        fontWeight: FontWeight.w700,
        letterSpacing: 0,
      ),
    );
  }
}

class _SettingsSurface extends StatelessWidget {
  const _SettingsSurface({
    required this.children,
    this.padding = const EdgeInsets.all(18),
  });

  final List<Widget> children;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: const Color(0xff1b1b1b),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.09)),
      ),
      child: Padding(
        padding: padding,
        child: Column(children: children),
      ),
    );
  }
}

class _PreferenceHeading extends StatelessWidget {
  const _PreferenceHeading({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Colors.white70),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: Colors.white)),
              const SizedBox(height: 2),
              Text(subtitle, style: const TextStyle(color: Colors.white54)),
            ],
          ),
        ),
      ],
    );
  }
}

class _ColorSwatch extends StatelessWidget {
  const _ColorSwatch({
    required this.option,
    required this.selected,
    required this.enabled,
    required this.onSelected,
  });

  final AccentOption option;
  final bool selected;
  final bool enabled;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: option.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: '${option.label} accent',
        child: InkWell(
          onTap: enabled ? onSelected : null,
          customBorder: const CircleBorder(),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: option.color,
              shape: BoxShape.circle,
              border: Border.all(
                color: selected ? Colors.white : Colors.transparent,
                width: 3,
              ),
            ),
            child: selected
                ? const Icon(Icons.check_rounded, color: Colors.black, size: 19)
                : null,
          ),
        ),
      ),
    );
  }
}

class _NavigationRow extends StatelessWidget {
  const _NavigationRow({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      leading: Icon(icon, color: Colors.white70),
      title: Text(label, style: const TextStyle(color: Colors.white)),
      trailing: const Icon(Icons.chevron_right_rounded, color: Colors.white38),
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 2),
    );
  }
}

class _SurfaceDivider extends StatelessWidget {
  const _SurfaceDivider({this.indent = 0});
  final double indent;

  @override
  Widget build(BuildContext context) {
    return Divider(
      height: 30,
      indent: indent,
      color: Colors.white.withValues(alpha: 0.09),
    );
  }
}

class _ChecklistItem extends StatelessWidget {
  const _ChecklistItem({
    required this.ok,
    required this.label,
    required this.detail,
    this.showDivider = true,
  });

  final bool ok;
  final String label;
  final String detail;
  final bool showDivider;

  @override
  Widget build(BuildContext context) {
    final statusColor = ok ? const Color(0xff7CFF6B) : const Color(0xffffb020);
    return Column(
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              ok ? Icons.check_circle_outline : Icons.info_outline,
              color: statusColor,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: Colors.white)),
                  const SizedBox(height: 3),
                  Text(
                    detail,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
        if (showDivider) const _SurfaceDivider(),
      ],
    );
  }
}
