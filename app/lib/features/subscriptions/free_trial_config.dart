/// Client-side free-trial length before live voice requires Duo Pro.
///
/// Trial start is stored per Google account in Firestore
/// (`subscribers/{googleId}`), with SharedPreferences as an offline cache.
///
/// ## Testing the paywall quickly
/// 1. Change [duration] to something short, e.g. `Duration(seconds: 30)`, **or**
/// 2. Launch with a dart-define override:
///    `flutter run --dart-define=ONE_ONE_FREE_TRIAL_SECONDS=30`
///
/// The dart-define wins when it is a positive integer. Ship with
/// [duration] = 7 days and no override. Short-trial QA builds use the local
/// cache only so sandbox / Firestore production clocks do not block tests.
class FreeTrialConfig {
  FreeTrialConfig._();

  /// Production trial length. Lower this while QA'ing the expired gate.
  static const Duration duration = Duration(days: 7);

  /// Effective trial length used by [FreeTrialAccess].
  static Duration get effectiveDuration {
    const overrideSeconds = int.fromEnvironment(
      'ONE_ONE_FREE_TRIAL_SECONDS',
      defaultValue: -1,
    );
    if (overrideSeconds > 0) {
      return Duration(seconds: overrideSeconds);
    }
    return duration;
  }

  /// True when [ONE_ONE_FREE_TRIAL_SECONDS] is set — QA runs use the local
  /// trial clock only and ignore RevenueCat Pro so sandbox entitlements do
  /// not bypass the gate.
  static bool get isShortTrialQa {
    const overrideSeconds = int.fromEnvironment(
      'ONE_ONE_FREE_TRIAL_SECONDS',
      defaultValue: -1,
    );
    return overrideSeconds > 0;
  }
}
