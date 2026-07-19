import 'package:shared_preferences/shared_preferences.dart';

import '../models/subscription_tier.dart';

/// Persists the first locally observed extreme-tier transition as a fallback
/// when Remote Config has not supplied a rollout timestamp.
///
/// Production rollouts should always set `subscription_extreme_activated_at_ms`
/// so every existing user receives the same 7/14-day deadline, including users
/// who do not open the app on the day the tier changes.
class SubscriptionGracePeriodStore {
  SubscriptionGracePeriodStore({
    required SharedPreferences preferences,
    int Function()? nowMs,
  }) : _preferences = preferences,
       _nowMs = nowMs ?? (() => DateTime.now().millisecondsSinceEpoch);

  static const String _localExtremeStartedAtKey =
      'one_one_extreme_tier_started_at_ms';

  final SharedPreferences _preferences;
  final int Function() _nowMs;

  Future<int?> resolveGraceEndsAt({
    required SubscriptionTier tier,
    required int gracePeriodDays,
    required int? remoteExtremeActivatedAtMs,
    Duration? graceDuration,
  }) async {
    if (tier != SubscriptionTier.extreme) {
      await _preferences.remove(_localExtremeStartedAtKey);
      return null;
    }

    final startedAt =
        remoteExtremeActivatedAtMs ??
        _preferences.getInt(_localExtremeStartedAtKey) ??
        _nowMs();
    if (remoteExtremeActivatedAtMs == null &&
        !_preferences.containsKey(_localExtremeStartedAtKey)) {
      await _preferences.setInt(_localExtremeStartedAtKey, startedAt);
    }

    final duration =
        graceDuration ?? Duration(days: gracePeriodDays);
    return startedAt + duration.inMilliseconds;
  }
}
