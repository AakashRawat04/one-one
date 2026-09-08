import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:one_one_app/app/app_config.dart';
import 'package:one_one_app/features/subscriptions/free_trial_config.dart';
import 'package:one_one_app/features/subscriptions/revenue_cat_service.dart';
import 'package:one_one_app/features/subscriptions/subscriber_access_record.dart';
import 'package:one_one_app/features/subscriptions/subscriber_access_store.dart';

/// Outcome of the free-trial / Pro access check for live voice.
enum FreeTrialAccessResult {
  /// Trial still running, or user already has Duo Pro.
  allow,

  /// Trial ended and user is not entitled — live voice is locked.
  requirePro,
}

/// Point-in-time trial + RevenueCat entitlement snapshot.
///
/// [entitledToPro] is always the RevenueCat entitlement. [trialActive] is
/// the Google-account-scoped trial clock (Firestore + local cache). Live
/// voice is allowed when either is true.
class DuoAccessSnapshot {
  const DuoAccessSnapshot({
    required this.entitledToPro,
    required this.trialActive,
    required this.remaining,
  });

  final bool entitledToPro;
  final bool trialActive;
  final Duration remaining;

  bool get canUseLiveVoice => entitledToPro || trialActive;
}

/// Thrown by the live-voice connect path when the free trial has ended and
/// the user is not entitled to Duo Pro.
///
/// Nudges and chat stay free forever — only live voice (`_goOnline`) checks
/// this. Callers should catch it to show tailored receiver/sender copy and
/// present [DuoGatePaywallScreen] with [DuoGatePaywallMode.voiceBlocked].
class VoicePaywallRequiredException implements Exception {
  const VoicePaywallRequiredException();

  @override
  String toString() => 'VoicePaywallRequiredException';
}

/// Persists and evaluates the per-Google-account free trial clock.
///
/// Source of truth is Firestore `subscribers/{googleId}` (see
/// [SubscriberAccessStore]). SharedPreferences is an offline cache only.
/// Reinstall / clear-data / second phone with the same Google account reuses
/// the original [trialStartedAt].
///
/// Prefs remain as a fallback when Firestore is unreachable; an existing
/// remote trial always wins over a missing/newer local clock.
class FreeTrialAccess {
  FreeTrialAccess._();

  /// Ensures a trial start timestamp exists for this Google account, then
  /// returns whether the user may use live voice.
  ///
  /// Pro entitlement always wins (except short-trial QA builds). If
  /// RevenueCat cannot be reached, the trial clock still applies.
  static Future<FreeTrialAccessResult> resolve({
    required String userId,
    Future<bool> Function()? isEntitledToPro,
  }) async {
    // QA builds with ONE_ONE_FREE_TRIAL_SECONDS rely on the local clock;
    // ignore RevenueCat so an active sandbox subscription does not skip the
    // gate while testing expiry.
    var entitled = false;
    if (!FreeTrialConfig.isShortTrialQa) {
      final checkPro = isEntitledToPro ?? _defaultIsEntitledToPro;
      entitled = await checkPro();
      if (entitled) {
        await syncSubscriberDebugState(userId: userId, entitledToPro: true);
        return FreeTrialAccessResult.allow;
      }
    }

    final startedAt = await ensureStarted(userId);
    final elapsed = DateTime.now().difference(startedAt);
    if (elapsed >= FreeTrialConfig.effectiveDuration) {
      await syncSubscriberDebugState(userId: userId, entitledToPro: entitled);
      return FreeTrialAccessResult.requirePro;
    }
    await syncSubscriberDebugState(userId: userId, entitledToPro: entitled);
    return FreeTrialAccessResult.allow;
  }

  /// RevenueCat entitlement + trial remaining. Starts the trial if needed
  /// when a signed-in user is present.
  static Future<DuoAccessSnapshot> snapshot({
    required String userId,
    Future<bool> Function()? isEntitledToPro,
  }) async {
    var entitled = false;
    if (!FreeTrialConfig.isShortTrialQa) {
      final checkPro = isEntitledToPro ?? _defaultIsEntitledToPro;
      entitled = await checkPro();
    }
    // Ensure clock exists so Settings remaining time is accurate.
    await ensureStarted(userId);
    final remaining = await FreeTrialAccess.remaining(userId);
    await syncSubscriberDebugState(userId: userId, entitledToPro: entitled);
    return DuoAccessSnapshot(
      entitledToPro: entitled,
      trialActive: remaining > Duration.zero,
      remaining: remaining,
    );
  }

  /// True when the post-trial illustrated paywall should appear once —
  /// trial over, not Pro, and not previously dismissed (Firestore or cache).
  static Future<bool> shouldShowPostTrialPaywall(String userId) async {
    final access = await resolve(userId: userId);
    if (access != FreeTrialAccessResult.requirePro) return false;
    return !(await _isPostTrialPaywallShown(userId));
  }

  /// Persists that the one-time post-trial paywall was shown (Firestore +
  /// local cache).
  static Future<void> markPostTrialPaywallShown(String userId) async {
    final user = _authUserMatching(userId);
    final subscriberId = user != null
        ? SubscriberAccessStore.subscriberIdFor(user)
        : userId;
    final local = await SubscriberAccessStore.readLocalCache(
      userId: userId,
      subscriberId: subscriberId,
    );
    final startedAt = local.startedAt ?? await ensureStarted(userId);
    await SubscriberAccessStore.cacheLocally(
      accountKey: subscriberId,
      userId: userId,
      trialStartedAt: startedAt,
      postTrialPaywallShown: true,
    );

    if (user == null) return;
    final remote = await SubscriberAccessStore.loadForUser(user);
    if (remote != null) {
      await SubscriberAccessStore.markPostTrialPaywallShown(remote);
      return;
    }
    await SubscriberAccessStore.ensureRecord(
      user: user,
      trialStartedAt: startedAt,
      trialDuration: FreeTrialConfig.effectiveDuration,
      postTrialPaywallShown: true,
    );
  }

  /// Writes / refreshes the trial start for this Google account.
  ///
  /// Firestore is authoritative when reachable. Local prefs cache the
  /// result for offline use and migrate older device-only trials into
  /// Firestore on first successful sync.
  static Future<DateTime> ensureStarted(String userId) async {
    final user = _authUserMatching(userId);
    final subscriberId = user != null
        ? SubscriberAccessStore.subscriberIdFor(user)
        : userId;
    final local = await SubscriberAccessStore.readLocalCache(
      userId: userId,
      subscriberId: subscriberId,
    );

    SubscriberAccessRecord? remote;
    if (user != null && !FreeTrialConfig.isShortTrialQa) {
      remote = await SubscriberAccessStore.loadForUser(user);
    }

    // Prefer the earliest known start so a reinstall cannot extend the trial.
    DateTime startedAt;
    if (remote != null) {
      startedAt = remote.trialStartedAt;
      if (local.startedAt != null && local.startedAt!.isBefore(startedAt)) {
        // Remote rules freeze trialStartedAtMs — keep remote, but log that
        // local was older (should only happen if clocks were manipulated).
        debugPrint(
          'FreeTrialAccess: local trial start ${local.startedAt} is older '
          'than Firestore ${remote.trialStartedAt}; using Firestore.',
        );
      }
    } else if (local.startedAt != null) {
      startedAt = local.startedAt!;
    } else {
      startedAt = DateTime.now();
    }

    final paywallShown = local.paywallShown || (remote?.postTrialPaywallShown ?? false);

    if (user != null && !FreeTrialConfig.isShortTrialQa) {
      try {
        final record = await SubscriberAccessStore.ensureRecord(
          user: user,
          trialStartedAt: startedAt,
          trialDuration: FreeTrialConfig.effectiveDuration,
          postTrialPaywallShown: paywallShown,
        );
        startedAt = record.trialStartedAt;
        await SubscriberAccessStore.cacheLocally(
          accountKey: record.subscriberId,
          userId: userId,
          trialStartedAt: startedAt,
          postTrialPaywallShown:
              paywallShown || record.postTrialPaywallShown,
        );
        return startedAt;
      } catch (error, stack) {
        debugPrint('FreeTrialAccess.ensureStarted Firestore sync failed: $error\n$stack');
      }
    }

    await SubscriberAccessStore.cacheLocally(
      accountKey: subscriberId,
      userId: userId,
      trialStartedAt: startedAt,
      postTrialPaywallShown: paywallShown,
    );
    return startedAt;
  }

  /// Remaining trial time, or [Duration.zero] if expired. If the clock has
  /// not started, returns the full trial length.
  static Future<Duration> remaining(String userId) async {
    final user = _authUserMatching(userId);
    final subscriberId = user != null
        ? SubscriberAccessStore.subscriberIdFor(user)
        : userId;

    if (user != null && !FreeTrialConfig.isShortTrialQa) {
      final remote = await SubscriberAccessStore.loadForUser(user);
      if (remote != null) {
        final left = FreeTrialConfig.effectiveDuration -
            DateTime.now().difference(remote.trialStartedAt);
        return left.isNegative ? Duration.zero : left;
      }
    }

    final local = await SubscriberAccessStore.readLocalCache(
      userId: userId,
      subscriberId: subscriberId,
    );
    final startedAt = local.startedAt;
    if (startedAt == null) return FreeTrialConfig.effectiveDuration;

    final left =
        FreeTrialConfig.effectiveDuration - DateTime.now().difference(startedAt);
    return left.isNegative ? Duration.zero : left;
  }

  /// Whole days remaining, rounded down from the stored start timestamp.
  static int remainingWholeDays(Duration remaining) {
    if (remaining <= Duration.zero) return 0;
    return remaining.inDays;
  }

  /// Best-effort Firestore debug snapshot of entitlement / identity fields.
  static Future<void> syncSubscriberDebugState({
    required String userId,
    required bool entitledToPro,
  }) async {
    final user = _authUserMatching(userId);
    if (user == null || FreeTrialConfig.isShortTrialQa) return;

    try {
      final remote = await SubscriberAccessStore.loadForUser(user);
      if (remote == null) return;

      String? rcAppUserId;
      var productIds = const <String>[];
      try {
        final info = await Purchases.getCustomerInfo();
        rcAppUserId = info.originalAppUserId;
        productIds = info.entitlements.active.values
            .map((entitlement) => entitlement.productIdentifier)
            .where((id) => id.isNotEmpty)
            .toList(growable: false);
      } catch (_) {
        // Entitlement debug fields are best-effort.
      }

      await SubscriberAccessStore.syncMutableFields(
        remote.copyWith(
          userId: user.uid,
          email: user.email,
          displayName: user.displayName,
          authProvider: 'google.com',
          entitledToPro: entitledToPro,
          proEntitlementId:
              entitledToPro ? AppConfig.proEntitlementId : remote.proEntitlementId,
          revenueCatAppUserId: rcAppUserId ?? remote.revenueCatAppUserId,
          activeProductIds: productIds.isEmpty ? remote.activeProductIds : productIds,
          updatedAtMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
    } catch (error) {
      debugPrint('FreeTrialAccess.syncSubscriberDebugState failed: $error');
    }
  }

  /// Debug / QA: clear the local cache so the next [resolve] can begin a
  /// fresh local trial. Does **not** delete the Firestore subscriber doc
  /// (trial start is immutable by design).
  static Future<void> debugReset(String userId) async {
    final user = _authUserMatching(userId);
    await SubscriberAccessStore.clearLocalCache(
      userId: userId,
      subscriberId: user != null
          ? SubscriberAccessStore.subscriberIdFor(user)
          : null,
    );
  }

  /// Debug / QA: backdate the **local** start so the trial is already
  /// expired. Firestore remains unchanged unless this is a short-trial QA
  /// build (which ignores remote for access checks).
  static Future<void> debugExpireNow(String userId) async {
    final user = _authUserMatching(userId);
    final subscriberId = user != null
        ? SubscriberAccessStore.subscriberIdFor(user)
        : userId;
    final expiredStart = DateTime.now().subtract(
      FreeTrialConfig.effectiveDuration + const Duration(seconds: 1),
    );
    await SubscriberAccessStore.cacheLocally(
      accountKey: subscriberId,
      userId: userId,
      trialStartedAt: expiredStart,
      postTrialPaywallShown: false,
    );
  }

  static Future<bool> _isPostTrialPaywallShown(String userId) async {
    final user = _authUserMatching(userId);
    final subscriberId = user != null
        ? SubscriberAccessStore.subscriberIdFor(user)
        : userId;
    if (user != null && !FreeTrialConfig.isShortTrialQa) {
      final remote = await SubscriberAccessStore.loadForUser(user);
      if (remote != null && remote.postTrialPaywallShown) return true;
    }
    final local = await SubscriberAccessStore.readLocalCache(
      userId: userId,
      subscriberId: subscriberId,
    );
    return local.paywallShown;
  }

  static User? _authUserMatching(String userId) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.uid != userId) return null;
    return user;
  }

  static Future<bool> _defaultIsEntitledToPro() async {
    try {
      final rc = await RevenueCatService.initialize();
      return rc.isEntitledToPro();
    } catch (_) {
      return false;
    }
  }
}
