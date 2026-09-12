import 'package:one_one_app/one_one.dart';

enum _SetupStep { mic, notification, background }

class _StepVisual {
  const _StepVisual({
    required this.iconColor,
    required this.icon,
    required this.backgroundAsset,
    required this.imageWidth,
    required this.imageHeight,
    this.boxTopColor,
    this.boxBottomColor,
    this.containScale = 1,
    this.shiftX = 0,
  });

  final Color iconColor;
  final IconData icon;
  final String backgroundAsset;

  /// Intrinsic pixel size of the artwork. Used to compute how much of the
  /// screen the contained image occupies so letterbox bands sit at the
  /// image's actual edges.
  final double imageWidth;
  final double imageHeight;

  /// Backdrop color at the artwork's top edge. When both top and bottom are
  /// set, the image is fitted with `BoxFit.contain` inside a box painted
  /// with those colors so the letterbox matches the illustration.
  final Color? boxTopColor;

  /// Backdrop color at the artwork's bottom edge.
  final Color? boxBottomColor;

  /// Multiplier on the max contain size. Values below 1 inset the artwork
  /// so more of the matching backdrop shows around it.
  final double containScale;

  /// Horizontal offset (logical px) applied to the image. Used to nudge a
  /// step's artwork right by a fixed amount.
  final double shiftX;
}

/// Icon colors are picked to match the dominant tone of each onboarding
/// background image so the CTA card feels native to the artwork behind it.
///
/// Screen 1 (green) and screen 3 (mustard) wrap their artwork in a box
/// painted with the illustration's own backdrop so the contained image
/// blends into the letterbox. Screen 2 (purple) stays contained at full
/// size with a matching purple letterbox.
///
/// Screen 3 swaps to [MarketSnapshot.permissionSetupScreen3Asset] for
/// Play markets outside India (`abroad_onboarding3.png`).
Map<_SetupStep, _StepVisual> _stepVisualsFor(MarketSnapshot snapshot) {
  final screen3Abroad = snapshot.usesAbroadOnboardingArt;
  return {
    _SetupStep.mic: const _StepVisual(
      iconColor: Color(0xff8fa83e),
      icon: Icons.mic_rounded,
      backgroundAsset: 'assets/Onboarding1.png',
      imageWidth: 848,
      imageHeight: 1264,
      // Screen 1 — uniform lime green (rgb 139,161,80).
      boxTopColor: Color(0xff8BA150),
      boxBottomColor: Color(0xff8BA150),
    ),
    _SetupStep.notification: const _StepVisual(
      iconColor: Color(0xff7a4fc9),
      icon: Icons.notifications_rounded,
      backgroundAsset: 'assets/Onboarding3.png',
      imageWidth: 712,
      imageHeight: 1264,
      // Screen 2 — uniform purple (rgb 95,40,121). Full contain, no extra inset.
      boxTopColor: Color(0xff5F2879),
      boxBottomColor: Color(0xff5F2879),
    ),
    _SetupStep.background: _StepVisual(
      iconColor: const Color(0xffE9A51C),
      icon: Icons.battery_saver_rounded,
      backgroundAsset: snapshot.permissionSetupScreen3Asset,
      // Abroad art is taller (941×1671); India art is 816×1287.
      imageWidth: screen3Abroad ? 941 : 816,
      imageHeight: screen3Abroad ? 1671 : 1287,
      // Screen 3 — unified illustration yellow. Scale below 1 so the
      // artwork sits with a matching yellow border around it.
      boxTopColor: Color(screen3Abroad ? 0xffE8A30E : 0xffE9A51C),
      boxBottomColor: Color(screen3Abroad ? 0xffE8A30E : 0xffE9A51C),
      containScale: 0.78,
    ),
  };
}

class SetupPermissionScreen extends StatefulWidget {
  const SetupPermissionScreen({super.key, required this.onComplete});

  /// Letterbox / scaffold color for the mic step (`Onboarding1.png`).
  /// Used by [StartupGateScreen] as a post-auth loading underlay so the
  /// handoff from Google sign-in does not flash brand yellow.
  static const firstStepBackgroundColor = Color(0xff8BA150);

  final Future<void> Function() onComplete;

  @override
  State<SetupPermissionScreen> createState() => _SetupPermissionScreenState();
}

class _SetupPermissionScreenState extends State<SetupPermissionScreen>
    with WidgetsBindingObserver {
  static const Duration _stageTransitionDuration = Duration(milliseconds: 320);

  _SetupStep _step = _SetupStep.mic;
  bool _micGranted = false;
  bool _notificationGranted = false;
  bool _backgroundGranted = false;
  bool _busy = false;
  bool _completed = false;

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
    if (state == AppLifecycleState.resumed &&
        _step == _SetupStep.background &&
        _busy &&
        !_completed) {
      unawaited(_finishBackgroundPermission());
    }
  }

  Future<void> _requestMicPermission() async {
    if (_busy || _step != _SetupStep.mic) return;

    setState(() => _busy = true);
    final status = await Permission.microphone.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() => _busy = false);
      _showDeniedSnackBar('Microphone permission is required.');
      return;
    }

    setState(() => _micGranted = true);
    await Future<void>.delayed(_stageTransitionDuration);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _step = _SetupStep.notification;
    });
  }

  Future<void> _requestNotificationPermission() async {
    if (_busy || _step != _SetupStep.notification) return;

    setState(() => _busy = true);
    final status = await Permission.notification.request();
    if (!mounted) return;

    if (!status.isGranted) {
      setState(() {
        _busy = false;
        _step = _SetupStep.background;
      });
      _showDeniedSnackBar(
        'Notifications can be enabled later in Android Settings.',
      );
      return;
    }

    setState(() => _notificationGranted = true);
    await Future<void>.delayed(_stageTransitionDuration);
    if (!mounted) return;

    setState(() {
      _busy = false;
      _step = _SetupStep.background;
    });
  }

  Future<void> _requestBackgroundPermission() async {
    if (_busy || _step != _SetupStep.background || _completed) return;
    setState(() => _busy = true);

    try {
      if (Platform.isAndroid && !await _isBackgroundActivityAllowed()) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
      await _finishBackgroundPermission();
    } catch (_) {
      if (!mounted || _completed) return;
      setState(() => _busy = false);
      _showDeniedSnackBar(
        'Allow background activity so nudges can reach you reliably.',
      );
    }
  }

  Future<void> _finishBackgroundPermission() async {
    if (!mounted || _completed || _step != _SetupStep.background) return;

    final granted = await _isBackgroundActivityAllowed();
    if (!mounted || _completed) return;
    if (!granted) {
      _completed = true;
      await widget.onComplete();
      return;
    }

    _completed = true;
    setState(() => _backgroundGranted = true);
    await Future<void>.delayed(_stageTransitionDuration);
    if (!mounted) return;
    try {
      await widget.onComplete();
    } catch (_) {
      if (!mounted) return;
      _completed = false;
      setState(() => _busy = false);
      _showDeniedSnackBar(context.l10n.permissionSetupFailed);
    }
  }

  Future<bool> _isBackgroundActivityAllowed() async {
    if (!Platform.isAndroid) return true;
    try {
      return await FlutterForegroundTask.isIgnoringBatteryOptimizations;
    } catch (_) {
      return false;
    }
  }

  void _showDeniedSnackBar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  /// Backdrop used to fill the screen around a contained illustration.
  /// Falls back to black for full-bleed `cover` steps.
  Color _backdropColor(_StepVisual visual) =>
      visual.boxTopColor ?? const Color(0xff000000);

  /// Renders the step's artwork.
  ///
  /// Screens with a [boxTopColor]/[boxBottomColor] pair wrap their artwork in
  /// a box painted with the illustration's own backdrop color, fitted with
  /// `BoxFit.contain` (and optional [containScale] inset).
  /// When top and bottom colors differ, a vertical gradient is aligned to
  /// the contained image's edges. Screens without a box keep the full-bleed
  /// `BoxFit.cover` and only apply a horizontal [shiftX] offset.
  Widget _buildStepBackground(_StepVisual visual) {
    final hasBox = visual.boxTopColor != null && visual.boxBottomColor != null;
    if (!hasBox) {
      Widget image = Image.asset(
        visual.backgroundAsset,
        key: ValueKey(visual.backgroundAsset),
        fit: BoxFit.cover,
        width: double.infinity,
        height: double.infinity,
        alignment: Alignment.center,
      );
      if (visual.shiftX != 0) {
        image = Transform.translate(
          offset: Offset(visual.shiftX, 0),
          child: image,
        );
      }
      return KeyedSubtree(key: ValueKey(visual.backgroundAsset), child: image);
    }

    return KeyedSubtree(
      key: ValueKey(visual.backgroundAsset),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final maxWidth = constraints.maxWidth.isFinite
              ? constraints.maxWidth
              : MediaQuery.sizeOf(context).width;
          final maxHeight = constraints.maxHeight.isFinite
              ? constraints.maxHeight
              : MediaQuery.sizeOf(context).height;
          final scale =
              min(
                maxWidth / visual.imageWidth,
                maxHeight / visual.imageHeight,
              ) *
              visual.containScale;
          final displayedWidth = visual.imageWidth * scale;
          final displayedHeight = visual.imageHeight * scale;
          final topBand = (maxHeight - displayedHeight) / 2;
          final usesGradient = visual.boxTopColor != visual.boxBottomColor;
          return ColoredBox(
            color: visual.boxTopColor!,
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: usesGradient
                    ? LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [visual.boxTopColor!, visual.boxBottomColor!],
                        stops: [
                          topBand / maxHeight,
                          (topBand + displayedHeight) / maxHeight,
                        ],
                      )
                    : null,
              ),
              child: Center(
                child: SizedBox(
                  width: displayedWidth,
                  height: displayedHeight,
                  child: Image.asset(
                    visual.backgroundAsset,
                    fit: BoxFit.fill,
                    width: displayedWidth,
                    height: displayedHeight,
                    gaplessPlayback: true,
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<MarketSnapshot>(
      valueListenable: MarketController.snapshot,
      builder: (context, snapshot, _) {
        final visual = _stepVisualsFor(snapshot)[_step]!;
        final backdrop = _backdropColor(visual);

        return Scaffold(
          backgroundColor: backdrop,
          body: Stack(
            fit: StackFit.expand,
            children: [
              Positioned.fill(child: ColoredBox(color: backdrop)),
              AnimatedSwitcher(
                duration: _stageTransitionDuration,
                switchInCurve: Curves.easeOutCubic,
                switchOutCurve: Curves.easeInCubic,
                layoutBuilder: (currentChild, previousChildren) {
                  return Stack(
                    fit: StackFit.expand,
                    alignment: Alignment.center,
                    children: [
                      ...previousChildren,
                      if (currentChild != null) currentChild,
                    ],
                  );
                },
                transitionBuilder: (child, animation) {
                  return FadeTransition(opacity: animation, child: child);
                },
                child: _buildStepBackground(visual),
              ),
              // Bottom scrim so the CTA card and footnote stay legible over
              // whatever part of the artwork ends up behind them.
              Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 320.h,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0),
                        Colors.black.withValues(alpha: 0.55),
                        Colors.black.withValues(alpha: 0.88),
                      ],
                      stops: const [0, 0.45, 1],
                    ),
                  ),
                ),
              ),
              SafeArea(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24.w),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      AnimatedSwitcher(
                        duration: _stageTransitionDuration,
                        switchInCurve: Curves.easeOutCubic,
                        switchOutCurve: Curves.easeInCubic,
                        transitionBuilder: (child, animation) {
                          final offsetAnimation = Tween<Offset>(
                            begin: const Offset(0.12, 0),
                            end: Offset.zero,
                          ).animate(animation);
                          return FadeTransition(
                            opacity: animation,
                            child: SlideTransition(
                              position: offsetAnimation,
                              child: child,
                            ),
                          );
                        },
                        child: switch (_step) {
                          _SetupStep.mic => _PermissionCard(
                            key: const ValueKey('mic-card'),
                            iconColor: visual.iconColor,
                            icon: visual.icon,
                            title: context.l10n.permissionMicTitle,
                            subtitle: context.l10n.permissionMicSubtitle,
                            checked: _micGranted,
                            onTap: _requestMicPermission,
                          ),
                          _SetupStep.notification => _PermissionCard(
                            key: const ValueKey('notification-card'),
                            iconColor: visual.iconColor,
                            icon: visual.icon,
                            title: context.l10n.permissionNotificationsTitle,
                            subtitle:
                                context.l10n.permissionNotificationsSubtitle,
                            checked: _notificationGranted,
                            onTap: _requestNotificationPermission,
                          ),
                          _SetupStep.background => _PermissionCard(
                            key: const ValueKey('background-card'),
                            iconColor: visual.iconColor,
                            icon: visual.icon,
                            title: context.l10n.permissionBackgroundTitle,
                            subtitle: context.l10n.permissionBackgroundSubtitle,
                            checked: _backgroundGranted,
                            onTap: _requestBackgroundPermission,
                          ),
                        },
                      ),
                      SizedBox(height: 16.h),
                      Text(
                        context.l10n.permissionFootnote,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: const Color.fromRGBO(255, 255, 255, 0.72),
                          fontSize: 11.sp,
                          height: 1.2,
                        ),
                      ),
                      SizedBox(height: 28.h),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    super.key,
    required this.iconColor,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.checked,
    required this.onTap,
  });

  final Color iconColor;
  final IconData icon;
  final String title;
  final String subtitle;
  final bool checked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(horizontal: 16.w, vertical: 14.h),
        decoration: BoxDecoration(
          color: const Color(0xff131d28),
          borderRadius: BorderRadius.circular(24.r),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.22),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 34.w,
              height: 34.w,
              decoration: BoxDecoration(
                color: iconColor,
                borderRadius: BorderRadius.circular(10.r),
              ),
              child: Icon(icon, color: Colors.white, size: 20.sp),
            ),
            SizedBox(width: 12.w),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18.sp,
                      fontWeight: FontWeight.w700,
                      height: 1,
                    ),
                  ),
                  SizedBox(height: 4.h),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: const Color.fromRGBO(255, 255, 255, 0.68),
                      fontSize: 12.sp,
                      height: 1.2,
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12.w),
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 24.w,
              height: 24.w,
              decoration: BoxDecoration(
                color: checked ? Colors.white : Colors.transparent,
                borderRadius: BorderRadius.circular(6.r),
                border: Border.all(
                  color: checked
                      ? Colors.white
                      : const Color.fromRGBO(255, 255, 255, 0.32),
                  width: 1.6,
                ),
              ),
              child: checked
                  ? Icon(
                      Icons.check_rounded,
                      size: 16.sp,
                      color: const Color(0xff131d28),
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}
