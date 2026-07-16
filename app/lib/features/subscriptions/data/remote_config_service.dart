import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../models/subscription_tier.dart';

/// Reads subscription-tier flags from Firebase Remote Config so pricing
/// and grace-period values can be adjusted server-side without an app release.
class RemoteConfigService {
  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;

  // ── Remote Config keys ──────────────────────────────────────────────

  static const String _keyPricingTier = 'subscription_pricing_tier';
  static const String _keyGracePeriodDays = 'subscription_grace_period_days';

  // ── Defaults (applied before first fetch) ──────────────────────────

  static const String _defaultPricingTier = 'normal';
  static const int _defaultGracePeriodDays = 7;

  // ── Initialization ─────────────────────────────────────────────────

  Future<void> initialize() async {
    await _remoteConfig.setDefaults(<String, dynamic>{
      _keyPricingTier: _defaultPricingTier,
      _keyGracePeriodDays: _defaultGracePeriodDays,
    });

    await _remoteConfig.setConfigSettings(RemoteConfigSettings(
      fetchTimeout: const Duration(seconds: 10),
      minimumFetchInterval: const Duration(minutes: 5),
    ));

    await _remoteConfig.fetchAndActivate();
  }

  // ── Queries ────────────────────────────────────────────────────────

  SubscriptionTier get activeTier {
    final raw = _remoteConfig.getString(_keyPricingTier);
    return raw == 'extreme' ? SubscriptionTier.extreme : SubscriptionTier.normal;
  }

  int get gracePeriodDays {
    final raw = _remoteConfig.getInt(_keyGracePeriodDays);
    // Clamp to sensible values — must be 7 or 14.
    if (raw == 7 || raw == 14) return raw;
    return _defaultGracePeriodDays;
  }
}
