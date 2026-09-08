import 'package:one_one_app/one_one.dart';

/// Why the illustrated gate paywall is being shown.
enum DuoGatePaywallMode {
  /// Hard stop after the free trial — Get Pro or Log out.
  trialExpired,

  /// Live voice blocked after trial; nudges and chat stay free.
  voiceBlocked,
}

/// Illustrated full-screen gate shown when the free trial has ended.
///
/// Separate from [ElevenProPaywallScreen] (the in-app Duo Pro subscription
/// sheet opened from Settings). **Get Pro** on this screen opens that sheet;
/// the second button logs out (trial gate) or dismisses back to home (voice
/// gate).
///
/// Returns `true` when the user gains Duo Pro access.
class DuoGatePaywallScreen extends StatefulWidget {
  const DuoGatePaywallScreen({
    super.key,
    required this.mode,
    this.identityRepository,
    this.onUnlocked,
  });

  final DuoGatePaywallMode mode;
  final IdentityRepository? identityRepository;
  final Future<void> Function()? onUnlocked;

  static Future<bool> open(
    BuildContext context, {
    required DuoGatePaywallMode mode,
  }) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        barrierColor: const Color(0xffF8BE03),
        transitionDuration: const Duration(milliseconds: 320),
        reverseTransitionDuration: const Duration(milliseconds: 260),
        pageBuilder: (context, animation, secondaryAnimation) {
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.dark,
            child: DuoGatePaywallScreen(mode: mode),
          );
        },
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          final curved = CurvedAnimation(
            parent: animation,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic,
          );
          return FadeTransition(opacity: curved, child: child);
        },
      ),
    );
    return result ?? false;
  }

  @override
  State<DuoGatePaywallScreen> createState() => _DuoGatePaywallScreenState();
}

class _DuoGatePaywallScreenState extends State<DuoGatePaywallScreen> {
  bool _busy = false;

  bool get _isTrialGate => widget.mode == DuoGatePaywallMode.trialExpired;

  @override
  void initState() {
    super.initState();
    unawaited(
      AnalyticsService.logScreenView(
        screenName: _isTrialGate ? 'trial_expired_gate' : 'voice_gate_paywall',
      ),
    );
    unawaited(
      AnalyticsService.logPaywallViewed(
        source: _isTrialGate ? 'trial_expired' : 'voice_blocked',
      ),
    );
  }

  Future<void> _openDuoPro() async {
    if (_busy) return;
    setState(() => _busy = true);
    unawaited(
      AnalyticsService.logButtonClick(
        buttonName: 'get_pro',
        screenName: _isTrialGate ? 'trial_expired_gate' : 'voice_gate_paywall',
      ),
    );
    try {
      final purchased = await ElevenProPaywallScreen.open(context);
      if (!mounted) return;
      if (purchased) {
        await widget.onUnlocked?.call();
        if (!mounted) return;
        Navigator.of(context).pop(true);
        return;
      }
      final rc = await RevenueCatService.initialize();
      if (await rc.isEntitledToPro()) {
        await widget.onUnlocked?.call();
        if (!mounted) return;
        Navigator.of(context).pop(true);
      }
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(context.l10n.settingsPaywallFailed)),
      );
      debugPrint('Gate paywall Duo Pro error: $error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _secondaryAction() async {
    if (_busy) return;
    if (_isTrialGate) {
      final repo = widget.identityRepository;
      if (repo == null) return;
      setState(() => _busy = true);
      try {
        await repo.signOut();
      } catch (error) {
        if (!mounted) return;
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(error.toString())),
        );
      }
      return;
    }
    if (!mounted) return;
    Navigator.of(context).pop(false);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final title = _isTrialGate
        ? l10n.trialExpiredTitle
        : 'Live voice requires Duo Pro';
    final body = _isTrialGate
        ? l10n.trialExpiredBody
        : 'Your trial has ended. Nudges and chat stay free — '
            'upgrade to talk live again.';
    final primaryLabel = '${l10n.trialExpiredGetPro} ✨';
    final secondaryLabel = _isTrialGate
        ? l10n.settingsLogOut
        : 'Continue with nudges & chat';

    return PopScope(
      canPop: !_isTrialGate,
      child: Scaffold(
        backgroundColor: const Color(0xffF8BE03),
        body: Stack(
          fit: StackFit.expand,
          children: [
            Image.asset('assets/paywall.png', fit: BoxFit.cover),
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 8.h),
                    child: Center(
                      child: Image.asset(
                        'assets/logo.png',
                        height: 36.h,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Padding(
                    padding: EdgeInsets.fromLTRB(20.w, 0, 20.w, 20.h),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color(0xff101010),
                            fontSize: 20.sp,
                            fontWeight: FontWeight.w800,
                            height: 1.25,
                            letterSpacing: -0.2,
                          ),
                        ),
                        SizedBox(height: 6.h),
                        Text(
                          body,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color: const Color.fromRGBO(16, 16, 16, 0.62),
                            fontSize: 13.sp,
                            height: 1.45,
                          ),
                        ),
                        SizedBox(height: 20.h),
                        SizedBox(
                          width: double.infinity,
                          height: 54.h,
                          child: FilledButton(
                            onPressed: _busy ? null : () => unawaited(_openDuoPro()),
                            style: FilledButton.styleFrom(
                              backgroundColor: const Color(0xff101010),
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: const Color(0xff101010)
                                  .withValues(alpha: 0.45),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27.r),
                              ),
                            ),
                            child: _busy
                                ? SizedBox(
                                    width: 22.w,
                                    height: 22.w,
                                    child: const CircularProgressIndicator(
                                      strokeWidth: 2.4,
                                      color: Colors.white,
                                    ),
                                  )
                                : Text(
                                    primaryLabel,
                                    style: TextStyle(
                                      fontSize: 15.sp,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                          ),
                        ),
                        SizedBox(height: 10.h),
                        SizedBox(
                          width: double.infinity,
                          height: 54.h,
                          child: OutlinedButton(
                            onPressed: _busy ? null : () => unawaited(_secondaryAction()),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: const Color(0xff101010),
                              disabledForegroundColor: const Color(0xff101010)
                                  .withValues(alpha: 0.35),
                              side: BorderSide(
                                color: const Color(0xff101010)
                                    .withValues(alpha: 0.55),
                                width: 1.6,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(27.r),
                              ),
                            ),
                            child: Text(
                              secondaryLabel,
                              style: TextStyle(
                                fontSize: 14.sp,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
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
