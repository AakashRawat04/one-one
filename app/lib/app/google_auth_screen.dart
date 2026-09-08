import 'package:one_one_app/one_one.dart';

class GoogleAuthScreen extends StatefulWidget {
  const GoogleAuthScreen({super.key, this.initializing = false});

  /// When true, shows the splash-colored underlay only — never the signed-out
  /// welcome CTA. Used while Firebase is still initializing so a returning
  /// signed-in session never flashes "Welcome to Duo".
  final bool initializing;

  @override
  State<GoogleAuthScreen> createState() => _GoogleAuthScreenState();
}

class _GoogleAuthScreenState extends State<GoogleAuthScreen> {
  IdentityRepository? _identityRepository;
  bool _isSigningIn = false;
  String? _errorMessage;

  IdentityRepository get _repo => _identityRepository ??= IdentityRepository();

  @override
  void initState() {
    super.initState();
    if (!widget.initializing) {
      unawaited(
        AnalyticsService.logScreenView(
          screenName: 'google_auth',
          screenClass: 'GoogleAuthScreen',
        ),
      );
    }
    unawaited(DuoLocalization.start());
  }

  @override
  void dispose() {
    _identityRepository?.dispose();
    super.dispose();
  }

  Future<void> _continueWithGoogle() async {
    if (_isSigningIn) return;
    unawaited(
      AnalyticsService.logButtonClick(
        buttonName: 'continue_with_google',
        screenName: 'google_auth',
      ),
    );
    // IMMEDIATELY replace the welcome UI with the splash-colored underlay
    // so the user sees an instant transition rather than waiting on a
    // button spinner. The Firebase auth stream will swap this screen out
    // for StartupGateScreen once sign-in completes.
    setState(() {
      _isSigningIn = true;
      _errorMessage = null;
    });

    try {
      await _repo.signInWithGoogle();
      // On success the root Firebase auth stream advances to onboarding.
      // Don't touch _isSigningIn – leave this screen in its underlay state
      // until the StreamBuilder replaces it.
    } catch (error, stack) {
      final message = error.toString();
      final cancelled =
          message.contains('canceled') || message.contains('cancelled');
      if (!cancelled) {
        await CrashlyticsService.recordError(
          error,
          stack,
          reason: 'google_sign_in_failed',
        );
      }
      if (!mounted) return;
      setState(() {
        _isSigningIn = false;
        _errorMessage = _friendlyError(context, error);
      });
    }
  }

  String _friendlyError(BuildContext context, Object error) {
    final message = error.toString();
    if (message.contains('canceled') || message.contains('cancelled')) {
      return context.l10n.googleSignInCancelled;
    }
    return context.l10n.googleSignInFailed;
  }

  @override
  Widget build(BuildContext context) {
    // Firebase still booting, or Google sign-in just started: underlay only.
    // Matches StartupGateScreen so cold starts never flash the welcome CTA at
    // already-signed-in users.
    if (widget.initializing || _isSigningIn) {
      return const BrandSplashScreen();
    }

    // The real welcome/sign-in CTA is about to be shown — the native splash
    // (identical brand background) can come down now. Skip if this widget
    // was already replaced (e.g. auth restored to a signed-in session
    // between this build and the next frame); otherwise we'd drop the
    // splash onto StartupGateScreen's loading underlay.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      NativeSplashBridge.markReady();
    });

    return WelcomeOnboardingHost(
      child: Scaffold(
        backgroundColor: BrandSplashScreen.backgroundColor,
        body: SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(28.w, 28.h, 28.w, 24.h),
            child: Column(
              children: [
                Align(
                  alignment: Alignment.topRight,
                  child: const WelcomeLanguageToggle(),
                ),
                const Spacer(flex: 2),
                // Logo — static, no animation. Rendered in its final position
                // from the very first frame.
                Image.asset(
                  'assets/logo.png',
                  width: 172.w,
                  fit: BoxFit.contain,
                ),
                SizedBox(height: 36.h),
                Text(
                  context.l10n.welcomeTitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color(0xff252a2e),
                    fontSize: 26.sp,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                SizedBox(height: 10.h),
                Text(
                  context.l10n.welcomeSubtitle,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color.fromRGBO(37, 42, 46, 0.72),
                    fontSize: 14.sp,
                    height: 1.45,
                  ),
                ),
                const Spacer(flex: 3),
                if (_errorMessage != null) ...[
                  Text(
                    _errorMessage!,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: const Color(0xff7a2f2f),
                      fontSize: 12.sp,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 14.h),
                ],
                _GoogleSignInButton(
                  busy: false,
                  busyLabel: context.l10n.signingIn,
                  label: context.l10n.continueWithGoogle,
                  onTap: _continueWithGoogle,
                ),
                SizedBox(height: 22.h),
                Text(
                  context.l10n.termsFooter,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: const Color.fromRGBO(56, 64, 71, 0.72),
                    fontSize: 11.sp,
                  ),
                ),
                DebugMarketPanel(
                  compact: true,
                  accent: const Color(0xff252a2e),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GoogleSignInButton extends StatefulWidget {
  const _GoogleSignInButton({
    required this.busy,
    required this.onTap,
    required this.label,
    this.busyLabel = 'Signing in…',
  });
  final bool busy;
  final VoidCallback onTap;
  final String label;
  final String busyLabel;
  @override
  State<_GoogleSignInButton> createState() => _GoogleSignInButtonState();
}

class _GoogleSignInButtonState extends State<_GoogleSignInButton> {
  bool _pressed = false;
  @override
  Widget build(BuildContext context) => AnimatedScale(
    scale: _pressed ? .96 : 1,
    duration: const Duration(milliseconds: 100),
    child: Material(
      color: widget.busy ? Colors.white70 : Colors.white,
      borderRadius: BorderRadius.circular(27.r),
      child: InkWell(
        onTap: widget.busy ? null : widget.onTap,
        onTapDown: widget.busy ? null : (_) => setState(() => _pressed = true),
        onTapUp: widget.busy ? null : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        borderRadius: BorderRadius.circular(27.r),
        child: SizedBox(
          width: double.infinity,
          height: 54.h,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              widget.busy
                  ? SizedBox.square(
                      dimension: 19.w,
                      child: const CircularProgressIndicator(
                        strokeWidth: 2.3,
                        color: Color(0xff384047),
                      ),
                    )
                  : Text(
                      'G',
                      style: TextStyle(
                        fontSize: 19.sp,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
              SizedBox(width: 10.w),
              Text(
                widget.busy ? widget.busyLabel : widget.label,
                style: TextStyle(
                  color: const Color(0xff384047),
                  fontSize: 15.sp,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
