import 'package:one_one_app/one_one.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    required this.session,
    required this.identityRepository,
    this.manageableGroups = const [],
    this.onManageGroup,
  });

  final IdentitySession session;
  final IdentityRepository identityRepository;

  /// Groups this user created (owner). Empty when none are manageable.
  final List<GroupSummary> manageableGroups;

  /// Opens management for the chosen group. Returns true when the group
  /// membership ended (left/deleted) so Settings can close if needed.
  final Future<bool> Function(GroupSummary group)? onManageGroup;

  /// Opens settings drifting in from the left (settings control side).
  static Future<void> open(
    BuildContext context, {
    required IdentitySession session,
    required IdentityRepository identityRepository,
    List<GroupSummary> manageableGroups = const [],
    Future<bool> Function(GroupSummary group)? onManageGroup,
  }) {
    return Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        opaque: true,
        barrierColor: const Color(0xff101010),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light,
            child: ColoredBox(
              color: const Color(0xff101010),
              child: SettingsScreen(
                session: session,
                identityRepository: identityRepository,
                manageableGroups: manageableGroups,
                onManageGroup: onManageGroup,
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
              // From the left edge where the settings icon sits — not bottom-up.
              position: Tween<Offset>(
                begin: const Offset(-0.22, 0),
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
  late HapticsIntensity _hapticsIntensity = _session.settings.hapticsIntensity;
  late String _persistedAccentColorKey = _session.settings.accentColorKey;
  bool _saving = false;
  bool _accountActionInProgress = false;
  bool _hasUnsavedAccentPreview = false;
  int _titleTapCount = 0;
  DateTime? _lastTitleTapAt;

  /// While true, never rebuild this route from session listenable updates —
  /// parent rebuilds during the edit-profile sheet's deactivate race
  /// `_dependents.isEmpty` assertions.
  bool _profileEditorOpen = false;
  String? _message;
  DuoAccessSnapshot? _duoAccess;

  Future<List<AvatarAsset>>? _avatarsFuture;

  @override
  void initState() {
    super.initState();
    unawaited(
      AnalyticsService.logScreenView(
        screenName: 'settings',
        screenClass: 'SettingsScreen',
      ),
    );
    _avatarsFuture = AvatarAssets.loadAll();
    unawaited(HomeVisualVariantController.ensureLoaded());
    unawaited(_loadDuoAccess());
    final currentSession = widget.identityRepository.currentSession;
    if (currentSession != null && currentSession.userId == _session.userId) {
      _session = currentSession;
      _accentColorKey = currentSession.settings.accentColorKey;
      _hapticsIntensity = currentSession.settings.hapticsIntensity;
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
    // Keep data fresh without rebuilding while the edit-profile sheet (or its
    // nested photo picker) owns modal elements under this route.
    if (_profileEditorOpen) {
      _session = session;
      return;
    }
    // Defer: same-frame notify during an awaited save/pop can race Elements
    // that are mid-deactivate (_dependents.isEmpty).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _profileEditorOpen) return;
      final latest = widget.identityRepository.currentSession;
      if (latest == null || latest.userId != _session.userId) return;
      setState(() => _session = latest);
    });
  }

  bool get _hasUnsavedSettings => _accentColorKey != _persistedAccentColorKey;

  void _acceptSession(IdentitySession session) {
    _session = session;
  }

  /// Edit Profile: display name + full avatar/photo section. Saves via a
  /// pinned floating bar so the user never has to scroll to find it.
  Future<void> _openProfileEditor() async {
    _profileEditorOpen = true;
    _EditProfileSheetResult? result;
    try {
      result = await showModalBottomSheet<_EditProfileSheetResult>(
        context: context,
        isScrollControlled: true,
        useSafeArea: true,
        backgroundColor: const Color(0xff1b1b1b),
        barrierColor: Colors.black87,
        showDragHandle: true,
        // Keep the sheet alive until the reverse animation finishes so its
        // elements are not half-deactivated under a parent rebuild.
        builder: (sheetContext) {
          return _EditProfileSheet(
            session: _session,
            accentColorKey: _accentColorKey,
            avatarsFuture: _avatarsFuture,
            identityRepository: widget.identityRepository,
          );
        },
      );
    } finally {
      // Stay "open" for one more frame after the route is gone so any
      // deferred session listenable callbacks still skip setState while
      // modal dependents are clearing.
    }

    if (!mounted) {
      _profileEditorOpen = false;
      return;
    }

    // Two end-of-frame waits: (1) modal route dispose, (2) InheritedElement
    // dependent bookkeeping. Avoid `_dependents.isEmpty` races.
    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(Duration.zero);
    await WidgetsBinding.instance.endOfFrame;
    if (!mounted) {
      _profileEditorOpen = false;
      return;
    }

    final latest = widget.identityRepository.currentSession;
    setState(() {
      if (result?.session != null) {
        _acceptSession(result!.session!);
      } else if (latest != null && latest.userId == _session.userId) {
        _acceptSession(latest);
      }
      if (result?.message != null) {
        _message = result!.message;
      }
      _profileEditorOpen = false;
    });
  }

  void _handleSettingsTitleTap() {
    final now = DateTime.now();
    final last = _lastTitleTapAt;
    if (last == null || now.difference(last) > const Duration(seconds: 2)) {
      _titleTapCount = 1;
    } else {
      _titleTapCount += 1;
    }
    _lastTitleTapAt = now;
    if (_titleTapCount >= 7) {
      _titleTapCount = 0;
      unawaited(HomeVisualVariantController.unlockTesting());
      if (mounted) {
        setState(() => _message = context.l10n.settingsTestingUnlocked);
      }
    }
  }

  Future<void> _setAppLanguage(AppLanguage language) async {
    await LocaleController.setLanguage(language);
    try {
      final session = await widget.identityRepository.updateSettings(
        preferredLocale: language.languageCode,
      );
      if (!mounted) return;
      setState(() => _acceptSession(session));
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'settings_language_save_failed',
          feature: 'settings',
          screenName: 'settings',
        ),
      );
    }
  }

  Future<void> _setHapticsIntensity(HapticsIntensity value) async {
    if (_hapticsIntensity == value || _saving) return;
    final previous = _hapticsIntensity;
    setState(() {
      _hapticsIntensity = value;
      _message = null;
    });
    unawaited(_previewHaptics(value));
    try {
      final session = await widget.identityRepository.updateSettings(
        hapticsIntensity: value,
      );
      if (!mounted) return;
      setState(() => _acceptSession(session));
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'settings_haptics_save_failed',
          feature: 'settings',
          screenName: 'settings',
        ),
      );
      if (!mounted) return;
      setState(() {
        _hapticsIntensity = previous;
        _message = error.toString();
      });
    }
  }

  Future<void> _previewHaptics(HapticsIntensity value) async {
    await NudgeHaptics.playStart(value);
    if (value == HapticsIntensity.wild) {
      await Future<void>.delayed(const Duration(milliseconds: 700));
      NudgeHaptics.stopWild();
    }
  }

  Future<void> _saveAccentColor() async {
    unawaited(
      CrashlyticsService.log(
        'settings_prefs_save_start accent=$_accentColorKey',
      ),
    );
    setState(() {
      _saving = true;
      _message = null;
    });

    try {
      final session = await widget.identityRepository.updateSettings(
        accentColorKey: _accentColorKey,
      );
      unawaited(CrashlyticsService.log('settings_prefs_save_network_ok'));
      _persistedAccentColorKey = session.settings.accentColorKey;
      _hasUnsavedAccentPreview = false;
      // Apply accent after local flags are consistent; no-op if already set.
      AccentThemeController.setAccentKey(session.settings.accentColorKey);
      unawaited(CrashlyticsService.log('settings_prefs_accent_applied'));
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(CrashlyticsService.log('settings_prefs_save_setState'));
        setState(() {
          _acceptSession(session);
          _message = context.l10n.settingsSaved;
          _saving = false;
        });
      });
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'settings_prefs_save_failed',
          feature: 'settings',
          screenName: 'settings',
        ),
      );
      if (!mounted) return;
      setState(() {
        _message = error.toString();
        _saving = false;
      });
    }
  }

  String get _signedInEmail {
    final user = FirebaseAuth.instance.currentUser;
    final directEmail = user?.email?.trim();
    if (directEmail != null && directEmail.isNotEmpty) return directEmail;
    for (final provider in user?.providerData ?? const <UserInfo>[]) {
      final email = provider.email?.trim();
      if (email != null && email.isNotEmpty) return email;
    }
    return context.l10n.settingsGoogleAccount;
  }

  Future<void> _logOut() async {
    final l10n = context.l10n;
    final confirmed = await _confirmAccountAction(
      title: l10n.settingsLogOutTitle,
      message: l10n.settingsLogOutMessage,
      actionLabel: l10n.settingsLogOut,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _accountActionInProgress = true;
      _message = null;
    });
    try {
      await widget.identityRepository.signOut();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = error.toString());
    } finally {
      if (mounted) setState(() => _accountActionInProgress = false);
    }
  }

  Future<void> _deleteAccount() async {
    final l10n = context.l10n;
    final confirmed = await _confirmAccountAction(
      title: l10n.settingsDeleteAccountTitle,
      message: l10n.settingsDeleteAccountMessage,
      actionLabel: l10n.settingsDeleteAccount,
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    setState(() {
      _accountActionInProgress = true;
      _message = null;
    });
    try {
      await widget.identityRepository.deleteAccount();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/auth', (_) => false);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _message = context.l10n.settingsDeleteAccountFailed;
      });
    } finally {
      if (mounted) setState(() => _accountActionInProgress = false);
    }
  }

  Future<bool> _confirmAccountAction({
    required String title,
    required String message,
    required String actionLabel,
    bool destructive = false,
  }) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: Text(context.l10n.settingsCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: destructive
                    ? FilledButton.styleFrom(
                        backgroundColor: const Color(0xffb3261e),
                        foregroundColor: Colors.white,
                      )
                    : null,
                child: Text(actionLabel),
              ),
            ],
          ),
        ) ??
        false;
  }

  void _openLegalDocument(LegalDocument document) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => LegalDocumentScreen(document: document),
      ),
    );
  }

  Future<void> _openGroupManagement() async {
    final groups = widget.manageableGroups;
    final onManage = widget.onManageGroup;
    if (groups.isEmpty || onManage == null) return;

    final selected = await showModalBottomSheet<GroupSummary>(
      context: context,
      backgroundColor: const Color(0xff1b1b1b),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (sheetContext) {
        return BottomSystemSafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 12, 8, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(99),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    context.l10n.settingsManageGroup,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 14),
                  child: Text(
                    context.l10n.settingsManageGroupSubtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 12.5),
                  ),
                ),
                const SizedBox(height: 8),
                ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: groups.length,
                  separatorBuilder: (_, _) => Divider(
                    height: 1,
                    indent: 56,
                    color: Colors.white.withValues(alpha: 0.09),
                  ),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return ListTile(
                      onTap: () => Navigator.of(sheetContext).pop(group),
                      leading: const Icon(
                        Icons.group_outlined,
                        color: Colors.white70,
                      ),
                      title: Text(
                        group.name,
                        style: const TextStyle(color: Colors.white),
                      ),
                      trailing: const Icon(
                        Icons.chevron_right_rounded,
                        color: Colors.white38,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
    if (selected == null || !mounted) return;

    final groupEnded = await onManage(selected);
    if (groupEnded && mounted) Navigator.of(context).pop();
  }

  Future<void> _loadDuoAccess() async {
    final snapshot = await FreeTrialAccess.snapshot(userId: _session.userId);
    if (!mounted) return;
    setState(() => _duoAccess = snapshot);
  }

  String _duoProSubtitle(AppLocalizations l10n) {
    final access = _duoAccess;
    if (access == null) return l10n.settingsViewPlans;
    if (access.entitledToPro) return l10n.settingsDuoProActiveSubtitle;
    if (access.trialActive) {
      final days = FreeTrialAccess.remainingWholeDays(access.remaining);
      if (days <= 0) return l10n.settingsTrialLessThanADay;
      if (days == 1) return l10n.settingsTrialOneDayLeft;
      return l10n.settingsTrialDaysLeft(days);
    }
    return l10n.settingsFreePlanSubtitle;
  }

  /// Opens the in-app Duo Pro paywall (branded UI + RevenueCat packages).
  Future<void> _showPaywall() async {
    unawaited(
      AnalyticsService.logButtonClick(
        buttonName: 'duo_pro',
        screenName: 'settings',
      ),
    );
    unawaited(
      AnalyticsService.logFeatureSelected(
        feature: 'paywall',
        screenName: 'settings',
      ),
    );
    try {
      final purchased = await ElevenProPaywallScreen.open(context);
      if (!mounted) return;
      await _loadDuoAccess();
      if (purchased) {
        setState(() => _message = context.l10n.settingsWelcomeDuoPro);
      }
    } catch (error) {
      if (!mounted) return;
      setState(() => _message = context.l10n.settingsPaywallFailed);
      debugPrint('Paywall error: $error');
    }
  }

  /// Contact Team Duo from the Manage Subscription sheet.
  Future<void> _showManageSubscription() {
    return SubscriptionManagementSheet.show(context);
  }

  bool _permissionRequestInFlight = false;

  /// Re-triggers the mic permission prompt, then refreshes the device record
  /// so the settings checklist reflects the grant.
  Future<void> _requestMicPermission() async {
    if (_permissionRequestInFlight) return;
    _permissionRequestInFlight = true;
    try {
      final status = await Permission.microphone.request();
      if (!mounted) return;
      setState(
        () => _message = status.isGranted
            ? context.l10n.settingsMicGranted
            : context.l10n.settingsMicDenied,
      );
      await _refreshPermissions();
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  /// Re-triggers the notification permission prompt, then refreshes the
  /// device record so the settings checklist reflects the grant.
  Future<void> _requestNotificationPermission() async {
    if (_permissionRequestInFlight) return;
    _permissionRequestInFlight = true;
    try {
      final status = await Permission.notification.request();
      if (!mounted) return;
      setState(
        () => _message = status.isGranted
            ? context.l10n.settingsNotificationGranted
            : context.l10n.settingsNotificationDenied,
      );
      await _refreshPermissions();
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  /// Re-triggers the battery optimization request, then refreshes the device
  /// record so the settings checklist reflects the grant.
  Future<void> _requestBatteryOptimization() async {
    if (_permissionRequestInFlight) return;
    _permissionRequestInFlight = true;
    try {
      try {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      } catch (_) {
        // Best effort — the user can enable it from Android Settings.
      }
      if (!mounted) return;
      setState(
        () => _message = context.l10n.settingsBatteryRequestSent,
      );
      await _refreshPermissions();
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  /// Re-triggers the missing permissions required for closed-app receive
  /// (notifications + battery optimization), then refreshes the checklist.
  Future<void> _requestClosedAppPermissions() async {
    if (_permissionRequestInFlight) return;
    _permissionRequestInFlight = true;
    try {
      final session = _session.device;
      if (!session.notificationPermissionGranted) {
        await Permission.notification.request();
      }
      if (!session.batteryOptimizationIgnored) {
        try {
          await FlutterForegroundTask.requestIgnoreBatteryOptimization();
        } catch (_) {
          // Best effort.
        }
      }
      if (!mounted) return;
      await _refreshPermissions();
      setState(() => _message = context.l10n.settingsClosedAppChecked);
    } finally {
      _permissionRequestInFlight = false;
    }
  }

  /// Re-reads the live permission state and publishes the updated session so
  /// the checklist checkboxes reflect what was just granted.
  Future<void> _refreshPermissions() async {
    try {
      await widget.identityRepository.ensureIdentity();
    } catch (_) {
      // Best-effort — the checklist still shows the session we already have.
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = accentColorForKey(_accentColorKey);
    final showSaveButton = _hasUnsavedSettings || _saving;
    final closedAppReceiveReady =
        _session.device.notificationPermissionGranted &&
        _session.device.batteryOptimizationIgnored;

    return Scaffold(
      backgroundColor: const Color(0xff101010),
      appBar: AppBar(
        backgroundColor: const Color(0xff101010),
        foregroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: GestureDetector(
          onTap: _handleSettingsTitleTap,
          behavior: HitTestBehavior.opaque,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(context.l10n.settingsTitle),
          ),
        ),
        centerTitle: true,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      floatingActionButton: AnimatedSwitcher(
        duration: const Duration(milliseconds: 220),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.25),
              end: Offset.zero,
            ).animate(animation),
            child: child,
          ),
        ),
        child: showSaveButton
            ? SafeArea(
                key: const ValueKey('save-settings-floating-button'),
                minimum: const EdgeInsets.symmetric(horizontal: 20),
                child: SizedBox(
                  width: MediaQuery.sizeOf(context).width - 40,
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _saveAccentColor,
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
                    label: Text(l10n.settingsSaveColor),
                  ),
                ),
              )
            : const SizedBox.shrink(
                key: ValueKey('save-settings-button-hidden'),
              ),
      ),
      body: ColoredBox(
        color: const Color(0xff101010),
        child: SafeArea(
          top: false,
          child: ListView(
            padding: EdgeInsets.fromLTRB(20, 8, 20, showSaveButton ? 112 : 32),
            children: [
              _ProfileHeader(
                session: _session,
                accent: accent,
                enabled: !_saving && !_profileEditorOpen,
                onEditProfile: _openProfileEditor,
              ),
              const SizedBox(height: 22),
              if (widget.manageableGroups.isNotEmpty &&
                  widget.onManageGroup != null) ...[
                _SectionTitle(l10n.settingsSectionGroup),
                const SizedBox(height: 12),
                _SettingsSurface(
                  padding: EdgeInsets.zero,
                  children: [
                    _NavigationRow(
                      icon: Icons.group_outlined,
                      label: l10n.settingsManageGroup,
                      onTap: _openGroupManagement,
                    ),
                  ],
                ),
                const SizedBox(height: 28),
              ],
              _SectionTitle(l10n.settingsSectionPreferences),
              const SizedBox(height: 12),
              _SettingsSurface(
                children: [
                  _PreferenceHeading(
                    icon: Icons.palette_outlined,
                    title: l10n.settingsAccentColorTitle,
                    subtitle: l10n.settingsAccentColorSubtitle,
                  ),
                  const SizedBox(height: 16),
                  // Two rows of six — 12 accents fill both runs on phone widths.
                  LayoutBuilder(
                    builder: (context, constraints) {
                      const columns = 6;
                      const spacing = 12.0;
                      final swatchSize =
                          (constraints.maxWidth - spacing * (columns - 1)) /
                          columns;
                      return Wrap(
                        spacing: spacing,
                        runSpacing: spacing,
                        children: [
                          for (final option in accentOptions)
                            SizedBox(
                              width: swatchSize,
                              height: swatchSize,
                              child: _ColorSwatch(
                                option: option,
                                selected: _accentColorKey == option.key,
                                enabled: !_saving,
                                onSelected: () {
                                  setState(() {
                                    _accentColorKey = option.key;
                                    _hasUnsavedAccentPreview =
                                        option.key != _persistedAccentColorKey;
                                  });
                                  AccentThemeController.setAccentKey(
                                    option.key,
                                  );
                                },
                              ),
                            ),
                        ],
                      );
                    },
                  ),
                  const _SurfaceDivider(),
                  _PreferenceHeading(
                    icon: Icons.vibration_outlined,
                    title: l10n.settingsHapticsTitle,
                    subtitle: l10n.settingsHapticsSubtitle(
                      _hapticsIntensity.localizedSubtitle(l10n),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _HapticsTierRow(
                    selected: _hapticsIntensity,
                    accent: accent,
                    enabled: !_saving,
                    onSelected: _setHapticsIntensity,
                  ),
                ],
              ),
              SettingsLanguageSection(
                accent: accent,
                onLanguageSelected: _setAppLanguage,
              ),
              ValueListenableBuilder<bool>(
                valueListenable: HomeVisualVariantController.unlocked,
                builder: (context, testingUnlocked, _) {
                  if (!testingUnlocked || !kDebugMode) {
                    return const SizedBox.shrink();
                  }
                  return DebugMarketPanel(accent: accent);
                },
              ),
              const SizedBox(height: 28),
              _SectionTitle(l10n.settingsSectionBackground),
              const SizedBox(height: 12),
              _SettingsSurface(
                children: [
                  _ChecklistItem(
                    ok: _session.device.micPermissionGranted,
                    label: l10n.settingsMicPermission,
                    detail: _session.device.micPermissionGranted
                        ? l10n.settingsMicReady
                        : l10n.settingsMicRequired,
                    onTap: _requestMicPermission,
                  ),
                  _ChecklistItem(
                    ok: _session.device.notificationPermissionGranted,
                    label: l10n.settingsNotificationPermission,
                    detail: _session.device.notificationPermissionGranted
                        ? l10n.settingsNotificationReady
                        : l10n.settingsNotificationRequired,
                    onTap: _requestNotificationPermission,
                  ),
                  _ChecklistItem(
                    ok: _session.device.batteryOptimizationIgnored,
                    label: l10n.settingsBatteryOptimization,
                    detail: _session.device.batteryOptimizationIgnored
                        ? l10n.settingsBatteryUnrestricted
                        : l10n.settingsBatteryMayInterrupt,
                    onTap: _requestBatteryOptimization,
                  ),
                  _ChecklistItem(
                    ok: closedAppReceiveReady,
                    label: l10n.settingsClosedAppReceive,
                    detail: closedAppReceiveReady
                        ? l10n.settingsClosedAppReady
                        : l10n.settingsClosedAppRequired,
                    showDivider: false,
                    onTap: _requestClosedAppPermissions,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionTitle(l10n.settingsSectionLegal),
              const SizedBox(height: 12),
              _SettingsSurface(
                padding: EdgeInsets.zero,
                children: [
                  _NavigationRow(
                    icon: Icons.description_outlined,
                    label: l10n.settingsTerms,
                    onTap: () => _openLegalDocument(LegalDocument.terms),
                  ),
                  const _SurfaceDivider(indent: 52),
                  _NavigationRow(
                    icon: Icons.privacy_tip_outlined,
                    label: l10n.settingsPrivacy,
                    onTap: () => _openLegalDocument(LegalDocument.privacy),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionTitle(l10n.settingsSectionSubscription),
              const SizedBox(height: 12),
              _SettingsSurface(
                padding: EdgeInsets.zero,
                children: [
                  _ElevenProSettingsCard(
                    onTap: _showPaywall,
                    subtitle: _duoProSubtitle(l10n),
                  ),
                  const _SurfaceDivider(indent: 52),
                  _NavigationRow(
                    icon: Icons.mail_outline_rounded,
                    label: l10n.subContactTeam,
                    onTap: _showManageSubscription,
                  ),
                ],
              ),
              const SizedBox(height: 28),
              _SectionTitle(l10n.settingsSectionSupport),
              const SizedBox(height: 12),
              _SettingsSurface(
                padding: EdgeInsets.zero,
                children: [
                  _NavigationRow(
                    icon: Icons.feedback_outlined,
                    label: l10n.settingsSendFeedback,
                    onTap: () =>
                        showSendFeedbackSheet(context, userId: _session.userId),
                  ),
                  ValueListenableBuilder<bool>(
                    valueListenable: HomeVisualVariantController.unlocked,
                    builder: (context, unlocked, _) {
                      if (!unlocked) return const SizedBox.shrink();
                      return Column(
                        children: [
                          const _SurfaceDivider(indent: 52),
                          _NavigationRow(
                            icon: Icons.bug_report_outlined,
                            label: l10n.settingsDebugLogs,
                            onTap: () => showDebugLogsSheet(context),
                          ),
                        ],
                      );
                    },
                  ),
                ],
              ),
              ValueListenableBuilder<bool>(
                valueListenable: HomeVisualVariantController.unlocked,
                builder: (context, testingUnlocked, _) {
                  if (!testingUnlocked) return const SizedBox.shrink();
                  return Padding(
                    padding: const EdgeInsets.only(top: 28),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _SectionTitle(l10n.settingsTestingSection),
                        const SizedBox(height: 12),
                        ValueListenableBuilder<HomeVisualVariant>(
                          valueListenable: HomeVisualVariantController.current,
                          builder: (context, variant, _) {
                            return _SettingsSurface(
                              children: [
                                _PreferenceHeading(
                                  icon: Icons.science_outlined,
                                  title: l10n.settingsTestingHomeTitle,
                                  subtitle: l10n.settingsTestingHomeSubtitle,
                                ),
                                const SizedBox(height: 14),
                                for (final option
                                    in HomeVisualVariant.values) ...[
                                  _TestingVariantRow(
                                    variant: option,
                                    selected: variant == option,
                                    accent: accent,
                                    onTap: () => unawaited(
                                      HomeVisualVariantController.setVariant(
                                        option,
                                      ),
                                    ),
                                  ),
                                  if (option != HomeVisualVariant.values.last)
                                    const _SurfaceDivider(),
                                ],
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 28),
              _SectionTitle(l10n.settingsSectionAccount),
              const SizedBox(height: 12),
              _SettingsSurface(
                children: [
                  _PreferenceHeading(
                    icon: Icons.account_circle_outlined,
                    title: _signedInEmail,
                    subtitle: l10n.settingsSignedInWithGoogle,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _accountActionInProgress ? null : _logOut,
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                    ),
                    icon: _accountActionInProgress
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.logout_rounded),
                    label: Text(l10n.settingsLogOut),
                  ),
                  const SizedBox(height: 8),
                  TextButton.icon(
                    onPressed: _accountActionInProgress ? null : _deleteAccount,
                    style: TextButton.styleFrom(
                      minimumSize: const Size.fromHeight(48),
                      foregroundColor: const Color(0xffff8a80),
                    ),
                    icon: const Icon(Icons.delete_outline_rounded),
                    label: Text(l10n.settingsDeleteAccount),
                  ),
                ],
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
    required this.enabled,
    required this.onEditProfile,
  });

  final IdentitySession session;
  final Color accent;
  final bool enabled;
  final VoidCallback onEditProfile;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Stack(
          alignment: Alignment.bottomRight,
          children: [
            GestureDetector(
              onTap: enabled ? onEditProfile : null,
              child: Container(
                padding: const EdgeInsets.all(3),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: accent, width: 2),
                ),
                child: ProfileAvatar(
                  profilePhotoUrl: session.user.profilePhotoUrl,
                  profilePhotoBase64: session.user.profilePhotoBase64,
                  avatarAsset: session.user.avatarAsset,
                  radius: 48,
                  backgroundColor: const Color(0xff2b2b2b),
                  fallback: const Icon(
                    Icons.person_outline,
                    color: Colors.white54,
                    size: 42,
                  ),
                ),
              ),
            ),
            Material(
              color: accent,
              shape: const CircleBorder(),
              child: IconButton(
                tooltip: context.l10n.settingsEditProfile,
                onPressed: enabled ? onEditProfile : null,
                icon: const Icon(Icons.edit_outlined),
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
      ],
    );
  }
}

class _EditProfileSheetResult {
  const _EditProfileSheetResult({this.session, this.message});

  final IdentitySession? session;
  final String? message;
}

/// Self-contained edit-profile sheet. Owns the [TextEditingController] so
/// dispose is tied to the modal route's element tree — not a parent callback
/// that can fire while the field is still listening.
class _EditProfileSheet extends StatefulWidget {
  const _EditProfileSheet({
    required this.session,
    required this.accentColorKey,
    required this.avatarsFuture,
    required this.identityRepository,
  });

  final IdentitySession session;
  final String accentColorKey;
  final Future<List<AvatarAsset>>? avatarsFuture;
  final IdentityRepository identityRepository;

  @override
  State<_EditProfileSheet> createState() => _EditProfileSheetState();
}

class _EditProfileSheetState extends State<_EditProfileSheet> {
  late final TextEditingController _nameController;
  late IdentitySession _session;
  String? _pendingAvatarAsset;
  late _AvatarSectionMode _avatarSectionMode;
  bool _saving = false;
  bool _changingPhoto = false;

  @override
  void initState() {
    super.initState();
    _session = widget.session;
    _nameController = TextEditingController(text: _session.user.displayName);
    _avatarSectionMode = _session.user.avatarAsset != null
        ? _AvatarSectionMode.avatar
        : _AvatarSectionMode.photo;
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<Uint8List?> _pickPhoto({
    required bool recropCurrent,
    required String? currentUrl,
  }) {
    if (recropCurrent) {
      return ProfilePhotoEditor.recropNetworkPhoto(context, currentUrl!);
    }
    return ProfilePhotoEditor.pickAndCrop(context);
  }

  /// Drop focus first so [TextField] detaches cleanly before route pop.
  Future<void> _popSheet(_EditProfileSheetResult result) async {
    FocusManager.instance.primaryFocus?.unfocus();
    // Let the field process unfocus before the element tree starts deactivating.
    await Future<void>.delayed(Duration.zero);
    if (!mounted) return;
    Navigator.of(context).pop(result);
  }

  Future<void> _changePhoto() async {
    if (_saving || _changingPhoto) return;
    setState(() => _changingPhoto = true);
    try {
      unawaited(CrashlyticsService.log('settings_edit_profile_photo_start'));
      final bytes = await _pickPhoto(
        recropCurrent: false,
        currentUrl: _session.user.profilePhotoUrl,
      );
      if (bytes == null || !mounted) return;
      final session = await widget.identityRepository.updateProfilePhoto(bytes);
      unawaited(
        CrashlyticsService.log('settings_edit_profile_photo_network_ok'),
      );
      if (!mounted) return;
      setState(() {
        _session = session;
        _pendingAvatarAsset = null;
        _avatarSectionMode = _AvatarSectionMode.photo;
      });
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'settings_edit_profile_photo_failed',
          feature: 'settings',
          screenName: 'settings',
        ),
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    } finally {
      if (mounted) setState(() => _changingPhoto = false);
    }
  }

  Future<void> _save() async {
    if (_saving) return;
    final displayName = _nameController.text.trim();
    final nameChanged =
        displayName.isNotEmpty && displayName != _session.user.displayName;
    final avatarChanged =
        _pendingAvatarAsset != null &&
        _pendingAvatarAsset != _session.user.avatarAsset;

    if (!nameChanged && !avatarChanged) {
      unawaited(CrashlyticsService.log('settings_edit_profile_pop_no_change'));
      if (!mounted) return;
      await _popSheet(_EditProfileSheetResult(session: _session));
      return;
    }

    unawaited(
      CrashlyticsService.log(
        'settings_edit_profile_save_start '
        'name=$nameChanged avatar=$avatarChanged',
      ),
    );
    setState(() => _saving = true);
    try {
      var session = _session;
      if (nameChanged) {
        session = await widget.identityRepository.updateDisplayName(
          displayName,
        );
        unawaited(
          CrashlyticsService.log('settings_edit_profile_name_network_ok'),
        );
      }
      if (avatarChanged) {
        session = await widget.identityRepository.updatePresetAvatar(
          _pendingAvatarAsset!,
        );
        unawaited(
          CrashlyticsService.log('settings_edit_profile_avatar_network_ok'),
        );
      }
      if (!mounted) return;
      unawaited(CrashlyticsService.log('settings_edit_profile_pop'));
      // Capture results and close before any parent setState can race modal
      // deactivation. Local state is enough for this frame; the parent applies
      // the returned session after the route is fully gone.
      await _popSheet(
        _EditProfileSheetResult(
          session: session,
          message: context.l10n.settingsProfileUpdated,
        ),
      );
    } catch (error, stack) {
      unawaited(
        CrashlyticsService.recordError(
          error,
          stack,
          reason: 'settings_edit_profile_save_failed',
          feature: 'settings',
          screenName: 'settings',
        ),
      );
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final accent = accentColorForKey(widget.accentColorKey);
    final keyboardInset = MediaQuery.viewInsetsOf(context).bottom;
    final draftAsset = _pendingAvatarAsset ?? _session.user.avatarAsset;
    final nameTrimmed = _nameController.text.trim();
    final nameChanged =
        nameTrimmed.isNotEmpty && nameTrimmed != _session.user.displayName;
    final avatarChanged =
        _pendingAvatarAsset != null &&
        _pendingAvatarAsset != _session.user.avatarAsset;
    final hasChanges = nameChanged || avatarChanged;
    final busy = _saving || _changingPhoto;

    return Padding(
      padding: EdgeInsets.only(
        bottom: keyboardInset + bottomSystemInsetOf(context),
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            l10n.settingsEditProfile,
                            style: Theme.of(context).textTheme.headlineSmall
                                ?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            l10n.settingsEditProfileSubtitle,
                            style: const TextStyle(color: Colors.white60),
                          ),
                        ],
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: l10n.settingsClose,
                    onPressed: busy
                        ? null
                        : () => unawaited(
                            _popSheet(
                              _EditProfileSheetResult(session: _session),
                            ),
                          ),
                    icon: const Icon(Icons.close_rounded),
                    color: Colors.white70,
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(24, 18, 24, 24),
                children: [
                  TextField(
                    controller: _nameController,
                    autofocus: false,
                    textCapitalization: TextCapitalization.words,
                    textInputAction: TextInputAction.done,
                    onChanged: (_) => setState(() {}),
                    onSubmitted: busy ? null : (_) => _save(),
                    style: const TextStyle(color: Colors.white),
                    decoration: _darkInputDecoration(l10n.settingsDisplayName),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    l10n.settingsAvatarSection,
                    style: TextStyle(
                      color: Colors.white54,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0,
                    ),
                  ),
                  const SizedBox(height: 12),
                  _AvatarSection(
                    mode: _avatarSectionMode,
                    onModeChanged: (mode) =>
                        setState(() => _avatarSectionMode = mode),
                    avatarsFuture: widget.avatarsFuture,
                    selectedAsset: draftAsset,
                    accent: accent,
                    avatarSaving: _saving,
                    onAvatarSelected: (asset) {
                      setState(() {
                        _pendingAvatarAsset = asset;
                        _avatarSectionMode = _AvatarSectionMode.avatar;
                      });
                    },
                    showSaveAvatar: false,
                    onSaveAvatar: () {},
                    profilePhotoUrl: _session.user.profilePhotoUrl,
                    profilePhotoBase64: _session.user.profilePhotoBase64,
                    photoSaving: _changingPhoto,
                    onChangePhoto: _changePhoto,
                    enabled: !busy,
                  ),
                ],
              ),
            ),
            DecoratedBox(
              decoration: BoxDecoration(
                color: const Color(0xff1b1b1b),
                border: Border(
                  top: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.35),
                    blurRadius: 18,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 12),
                  child: FilledButton.icon(
                    onPressed: busy ? null : _save,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                      backgroundColor: hasChanges
                          ? accent
                          : accent.withValues(alpha: 0.55),
                      foregroundColor: Colors.black,
                    ),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : Icon(
                            hasChanges
                                ? Icons.check_rounded
                                : Icons.save_outlined,
                          ),
                    label: Text(
                      _saving
                          ? l10n.settingsSaving
                          : hasChanges
                          ? l10n.settingsSaveProfile
                          : l10n.settingsDone,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _AvatarSectionMode { avatar, photo }

/// Lets existing users switch between a bundled preset avatar and a custom
/// photo. Preset choice is a draft until Save; photo applies when uploaded.
class _AvatarSection extends StatelessWidget {
  const _AvatarSection({
    required this.mode,
    required this.onModeChanged,
    required this.avatarsFuture,
    required this.selectedAsset,
    required this.accent,
    required this.avatarSaving,
    required this.onAvatarSelected,
    required this.showSaveAvatar,
    required this.onSaveAvatar,
    required this.profilePhotoUrl,
    required this.profilePhotoBase64,
    required this.photoSaving,
    required this.onChangePhoto,
    required this.enabled,
  });

  final _AvatarSectionMode mode;
  final ValueChanged<_AvatarSectionMode> onModeChanged;
  final Future<List<AvatarAsset>>? avatarsFuture;
  final String? selectedAsset;
  final Color accent;
  final bool avatarSaving;
  final ValueChanged<String> onAvatarSelected;
  final bool showSaveAvatar;
  final VoidCallback onSaveAvatar;
  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
  final bool photoSaving;
  final VoidCallback onChangePhoto;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SegmentedButton<_AvatarSectionMode>(
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
          segments: [
            ButtonSegment(
              value: _AvatarSectionMode.avatar,
              icon: const Icon(Icons.face_retouching_natural_outlined),
              label: Text(context.l10n.settingsAvatar),
            ),
            ButtonSegment(
              value: _AvatarSectionMode.photo,
              icon: const Icon(Icons.photo_camera_outlined),
              label: Text(context.l10n.settingsPhoto),
            ),
          ],
          selected: {mode},
          onSelectionChanged: enabled
              ? (selection) => onModeChanged(selection.first)
              : null,
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: mode == _AvatarSectionMode.avatar
              ? _AvatarTabContent(
                  key: const ValueKey('avatar-tab'),
                  avatarsFuture: avatarsFuture,
                  selectedAsset: selectedAsset,
                  accent: accent,
                  enabled: enabled,
                  onAvatarSelected: onAvatarSelected,
                  showSave: showSaveAvatar,
                  onSave: onSaveAvatar,
                  saving: avatarSaving,
                )
              : _PhotoTabContent(
                  key: const ValueKey('photo-tab'),
                  profilePhotoUrl: profilePhotoUrl,
                  profilePhotoBase64: profilePhotoBase64,
                  accent: accent,
                  enabled: enabled,
                  saving: photoSaving,
                  onChangePhoto: onChangePhoto,
                ),
        ),
      ],
    );
  }
}

class _AvatarTabContent extends StatelessWidget {
  const _AvatarTabContent({
    super.key,
    required this.avatarsFuture,
    required this.selectedAsset,
    required this.accent,
    required this.enabled,
    required this.onAvatarSelected,
    required this.showSave,
    required this.onSave,
    required this.saving,
  });

  final Future<List<AvatarAsset>>? avatarsFuture;
  final String? selectedAsset;
  final Color accent;
  final bool enabled;
  final ValueChanged<String> onAvatarSelected;
  final bool showSave;
  final VoidCallback onSave;
  final bool saving;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<AvatarAsset>>(
      future: avatarsFuture,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 40),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }
        return Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Nested under Settings' ListView so every avatar across both
                // packs is reachable via the outer scroll.
                AvatarPickerGrid(
                  avatars: snapshot.data!,
                  selectedAsset: selectedAsset,
                  enabled: enabled,
                  accent: accent,
                  onAvatarSelected: onAvatarSelected,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                ),
                if (showSave) ...[
                  const SizedBox(height: 18),
                  FilledButton.icon(
                    onPressed: saving ? null : onSave,
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(50),
                      backgroundColor: accent,
                      foregroundColor: Colors.black,
                    ),
                    icon: saving
                        ? const SizedBox.square(
                            dimension: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.black,
                            ),
                          )
                        : const Icon(Icons.check_rounded),
                    label: Text(
                      saving
                          ? context.l10n.settingsSaving
                          : context.l10n.settingsSaveProfile,
                    ),
                  ),
                ],
              ],
            ),
            if (saving)
              const Positioned.fill(
                child: IgnorePointer(
                  child: ColoredBox(color: Color(0x661b1b1b)),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _PhotoTabContent extends StatelessWidget {
  const _PhotoTabContent({
    super.key,
    required this.profilePhotoUrl,
    required this.profilePhotoBase64,
    required this.accent,
    required this.enabled,
    required this.saving,
    required this.onChangePhoto,
  });

  final String? profilePhotoUrl;
  final String? profilePhotoBase64;
  final Color accent;
  final bool enabled;
  final bool saving;
  final VoidCallback onChangePhoto;

  @override
  Widget build(BuildContext context) {
    final hasPhoto =
        (profilePhotoUrl?.trim().isNotEmpty ?? false) ||
        (profilePhotoBase64?.trim().isNotEmpty ?? false);

    return Row(
      children: [
        ClipOval(
          child: SizedBox(
            width: 64,
            height: 64,
            child: ProfileImage(
              profilePhotoUrl: profilePhotoUrl,
              profilePhotoBase64: profilePhotoBase64,
              backgroundColor: const Color(0xff2b2b2b),
              fallback: const Icon(Icons.person_outline, color: Colors.white54),
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                hasPhoto
                    ? context.l10n.settingsYourPhoto
                    : context.l10n.settingsNoPhoto,
                style: const TextStyle(color: Colors.white),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: enabled ? onChangePhoto : null,
                style: OutlinedButton.styleFrom(
                  foregroundColor: accent,
                  side: BorderSide(color: accent),
                ),
                icon: saving
                    ? SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : const Icon(Icons.upload_outlined, size: 18),
                label: Text(
                  hasPhoto
                      ? context.l10n.settingsChangePhoto
                      : context.l10n.settingsUploadPhoto,
                ),
              ),
            ],
          ),
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

class _ElevenProSettingsCard extends StatelessWidget {
  const _ElevenProSettingsCard({
    required this.onTap,
    required this.subtitle,
  });

  final VoidCallback onTap;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(8)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 14, 14, 14),
        child: Row(
          children: [
            const Icon(Icons.workspace_premium_outlined, color: Colors.white70),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.settingsDuoPro,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Colors.white38),
          ],
        ),
      ),
    );
  }
}

class _HapticsTierRow extends StatelessWidget {
  const _HapticsTierRow({
    required this.selected,
    required this.accent,
    required this.enabled,
    required this.onSelected,
  });

  final HapticsIntensity selected;
  final Color accent;
  final bool enabled;
  final ValueChanged<HapticsIntensity> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final option in HapticsIntensity.values) ...[
          if (option != HapticsIntensity.values.first) const SizedBox(width: 8),
          Expanded(
            child: _HapticsTierChip(
              option: option,
              selected: selected == option,
              accent: accent,
              enabled: enabled,
              onTap: () => onSelected(option),
            ),
          ),
        ],
      ],
    );
  }
}

class _HapticsTierChip extends StatelessWidget {
  const _HapticsTierChip({
    required this.option,
    required this.selected,
    required this.accent,
    required this.enabled,
    required this.onTap,
  });

  final HapticsIntensity option;
  final bool selected;
  final Color accent;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final labelColor = selected ? accent : Colors.white54;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        splashColor: accent.withValues(alpha: 0.12),
        highlightColor: accent.withValues(alpha: 0.06),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Text(
                option.emoji,
                style: const TextStyle(fontSize: 28, height: 1.1),
              ),
              const SizedBox(height: 8),
              Text(
                option.localizedLabel(context.l10n),
                style: TextStyle(
                  color: labelColor,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 6),
              AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                curve: Curves.easeOut,
                height: 2,
                width: selected ? 28 : 0,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(1),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TestingVariantRow extends StatelessWidget {
  const _TestingVariantRow({
    required this.variant,
    required this.selected,
    required this.accent,
    required this.onTap,
  });

  final HomeVisualVariant variant;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(6),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off_outlined,
              color: selected ? accent : Colors.white38,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    variant.label,
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    variant.subtitle,
                    style: const TextStyle(color: Colors.white54, fontSize: 13),
                  ),
                ],
              ),
            ),
          ],
        ),
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
      message: option.localizedLabel(context.l10n),
      child: Semantics(
        button: true,
        selected: selected,
        label: option.localizedLabel(context.l10n),
        child: InkWell(
          onTap: enabled ? onSelected : null,
          customBorder: const CircleBorder(),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final side = constraints.biggest.shortestSide;
              final circle = (side * 0.75).clamp(28.0, 40.0);
              final checkSize = (circle * 0.53).clamp(14.0, 20.0);
              return Center(
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: circle,
                  height: circle,
                  decoration: BoxDecoration(
                    color: option.color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: selected ? Colors.white : Colors.transparent,
                      width: 3,
                    ),
                  ),
                  child: selected
                      ? Icon(
                          Icons.check_rounded,
                          color: Colors.black,
                          size: checkSize,
                        )
                      : null,
                ),
              );
            },
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
    this.onTap,
  });

  final bool ok;
  final String label;
  final String detail;
  final bool showDivider;

  /// Re-triggers the permission prompt when [ok] is false. When null the row
  /// is informational and not tappable.
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final statusColor = ok ? const Color(0xff7CFF6B) : const Color(0xffffb020);
    final tappable = !ok && onTap != null;
    return Column(
      children: [
        InkWell(
          onTap: tappable ? onTap : null,
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 2),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  ok ? Icons.check_box_rounded : Icons.check_box_outline_blank,
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
                        style: const TextStyle(
                          color: Colors.white54,
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        if (showDivider) const _SurfaceDivider(),
      ],
    );
  }
}
