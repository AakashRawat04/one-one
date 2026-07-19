import 'dart:async';

import 'package:firebase_remote_config/firebase_remote_config.dart';

import '../models/subscription_tier.dart';

/// Reads subscription-tier flags from Firebase Remote Config so pricing
/// and grace-period values can be adjusted server-side without an app release.
class RemoteConfigService {
  RemoteConfigService({FirebaseRemoteConfig? remoteConfig})
    : _remoteConfig = remoteConfig ?? FirebaseRemoteConfig.instance;

  final FirebaseRemoteConfig _remoteConfig;
  StreamSubscription<RemoteConfigUpdate>? _updateSubscription;
  final StreamController<void> _updates = StreamController<void>.broadcast();

  // ── Remote Config keys ──────────────────────────────────────────────

  static const String _keyPricingTier = 'subscription_pricing_tier';
  static const String _keyGracePeriodDays = 'subscription_grace_period_days';
  static const String _keyExtremeActivatedAtMs =
      'subscription_extreme_activated_at_ms';
  static const String _keyNormalIndiaOffering =
      'subscription_offering_normal_india';
  static const String _keyNormalInternationalOffering =
      'subscription_offering_normal_international';
  static const String _keyExtremeIndiaOffering =
      'subscription_offering_extreme_india';
  static const String _keyExtremeInternationalOffering =
      'subscription_offering_extreme_international';
  static const String _keyDeveloperRedeemEnabled =
      'subscription_developer_redeem_enabled';

  // ── Defaults (applied before first fetch) ──────────────────────────

  static const String _defaultPricingTier = 'normal';
  static const int _defaultGracePeriodDays = 7;
  static const String _defaultNormalIndiaOffering = 'normal_india';
  static const String _defaultNormalInternationalOffering =
      'normal_international';
  static const String _defaultExtremeIndiaOffering = 'extreme_india';
  static const String _defaultExtremeInternationalOffering =
      'extreme_international';

  // ── Initialization ─────────────────────────────────────────────────

  Future<void> initialize() async {
    await _remoteConfig.setDefaults(<String, dynamic>{
      _keyPricingTier: _defaultPricingTier,
      _keyGracePeriodDays: _defaultGracePeriodDays,
      _keyExtremeActivatedAtMs: 0,
      _keyNormalIndiaOffering: _defaultNormalIndiaOffering,
      _keyNormalInternationalOffering: _defaultNormalInternationalOffering,
      _keyExtremeIndiaOffering: _defaultExtremeIndiaOffering,
      _keyExtremeInternationalOffering: _defaultExtremeInternationalOffering,
      _keyDeveloperRedeemEnabled: false,
    });

    await _remoteConfig.setConfigSettings(
      RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(minutes: 5),
      ),
    );

    await _remoteConfig.fetchAndActivate();
    _updateSubscription ??= _remoteConfig.onConfigUpdated.listen((_) async {
      await _remoteConfig.activate();
      if (!_updates.isClosed) _updates.add(null);
    });
  }

  Stream<void> get updates => _updates.stream;

  // ── Queries ────────────────────────────────────────────────────────

  SubscriptionTier get activeTier {
    final raw = _remoteConfig.getString(_keyPricingTier);
    return raw == 'extreme'
        ? SubscriptionTier.extreme
        : SubscriptionTier.normal;
  }

  int get gracePeriodDays {
    final raw = _remoteConfig.getInt(_keyGracePeriodDays);
    // Clamp to sensible values — must be 7 or 14.
    if (raw == 7 || raw == 14) return raw;
    return _defaultGracePeriodDays;
  }

  int? get extremeActivatedAtMs {
    final value = _remoteConfig.getInt(_keyExtremeActivatedAtMs);
    return value > 0 ? value : null;
  }

  bool get developerRedeemEnabled =>
      _remoteConfig.getBool(_keyDeveloperRedeemEnabled);

  String offeringId({required SubscriptionTier tier, required bool isIndia}) {
    final key = switch ((tier, isIndia)) {
      (SubscriptionTier.normal, true) => _keyNormalIndiaOffering,
      (SubscriptionTier.normal, false) => _keyNormalInternationalOffering,
      (SubscriptionTier.extreme, true) => _keyExtremeIndiaOffering,
      (SubscriptionTier.extreme, false) => _keyExtremeInternationalOffering,
    };
    final value = _remoteConfig.getString(key).trim();
    if (value.isNotEmpty) return value;
    return switch ((tier, isIndia)) {
      (SubscriptionTier.normal, true) => _defaultNormalIndiaOffering,
      (SubscriptionTier.normal, false) => _defaultNormalInternationalOffering,
      (SubscriptionTier.extreme, true) => _defaultExtremeIndiaOffering,
      (SubscriptionTier.extreme, false) => _defaultExtremeInternationalOffering,
    };
  }

  Future<void> dispose() async {
    await _updateSubscription?.cancel();
    await _updates.close();
  }
}
