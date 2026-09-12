import 'package:one_one_app/one_one.dart';

/// Bridges to the native Android splash (`MainActivity.installSplashScreen`
/// + `setKeepOnScreenCondition`). The native splash owns the branded logo
/// and stays on top of engine boot, Firebase init, and identity/group
/// prefetch until this fires. Flutter loading widgets underneath must not
/// paint a second logo — they only match the splash background so a
/// premature native dismiss does not flash a different-looking screen.
///
/// Safe to call from multiple call sites and multiple times; only the first
/// call has any effect.
class NativeSplashBridge {
  NativeSplashBridge._();

  static const MethodChannel _channel = MethodChannel('app/splash');
  static bool _sent = false;

  /// Whether [markReady] has already run. After the welcome CTA has shown,
  /// subsequent loading gates must not paint the brand-yellow underlay —
  /// that flash is visible (e.g. Google account picker → permission setup).
  static bool get isReady => _sent;

  /// Tells the native side the first real, interactive screen (sign-in CTA,
  /// home, onboarding, or an error screen) is on screen and it's safe to
  /// dismiss the native splash.
  static void markReady() {
    if (_sent) return;
    _sent = true;
    unawaited(_channel.invokeMethod<void>('flutterReady').catchError((_) {}));
  }
}
