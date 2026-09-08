import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:one_one_app/app/app_config.dart';
import 'package:one_one_app/features/subscriptions/subscriber_access_record.dart';

/// Resolves Google-account-scoped subscriber docs in Firestore.
///
/// Collection layout (Firestore, not RTDB):
/// - `subscribers/{googleId}` — trial + subscription debug record
/// - `subscriberByUserId/{firebaseUid}` — index from Auth uid → googleId
class SubscriberAccessStore {
  SubscriberAccessStore._();

  static const subscribersCollection = 'subscribers';
  static const byUserIdCollection = 'subscriberByUserId';

  static FirebaseFirestore get _db => FirebaseFirestore.instance;

  /// Stable Google account id when signed in with Google; else Firebase uid.
  static String subscriberIdFor(User user) {
    final google = user.providerData
        .where((provider) => provider.providerId == 'google.com')
        .map((provider) => provider.uid?.trim() ?? '')
        .where((uid) => uid.isNotEmpty)
        .firstOrNull;
    if (google != null) return google;
    return user.uid;
  }

  static String? googleIdFor(User user) {
    final google = user.providerData
        .where((provider) => provider.providerId == 'google.com')
        .map((provider) => provider.uid?.trim() ?? '')
        .where((uid) => uid.isNotEmpty)
        .firstOrNull;
    return google;
  }

  static Future<SubscriberAccessRecord?> loadForUser(User user) async {
    final subscriberId = subscriberIdFor(user);
    try {
      final byGoogle = await _db
          .collection(subscribersCollection)
          .doc(subscriberId)
          .get();
      if (byGoogle.exists && byGoogle.data() != null) {
        return SubscriberAccessRecord.fromFirestoreMap(
          byGoogle.id,
          byGoogle.data()!,
        );
      }

      // Legacy / race: index by Firebase uid may point at an existing doc.
      final index = await _db.collection(byUserIdCollection).doc(user.uid).get();
      final indexedId = index.data()?['subscriberId']?.toString();
      if (indexedId != null && indexedId.isNotEmpty && indexedId != subscriberId) {
        final byIndex = await _db
            .collection(subscribersCollection)
            .doc(indexedId)
            .get();
        if (byIndex.exists && byIndex.data() != null) {
          return SubscriberAccessRecord.fromFirestoreMap(
            byIndex.id,
            byIndex.data()!,
          );
        }
      }
    } catch (error, stack) {
      debugPrint('SubscriberAccessStore.loadForUser failed: $error\n$stack');
    }
    return null;
  }

  /// Creates the subscriber doc if missing. Never overwrites an existing
  /// [SubscriberAccessRecord.trialStartedAtMs].
  static Future<SubscriberAccessRecord> ensureRecord({
    required User user,
    required DateTime trialStartedAt,
    required Duration trialDuration,
    bool postTrialPaywallShown = false,
    bool entitledToPro = false,
    String? revenueCatAppUserId,
    List<String> activeProductIds = const [],
    String? lastDeviceId,
  }) async {
    final existing = await loadForUser(user);
    if (existing != null) {
      await syncMutableFields(
        existing.copyWith(
          userId: user.uid,
          email: user.email,
          displayName: user.displayName,
          authProvider: 'google.com',
          postTrialPaywallShown:
              existing.postTrialPaywallShown || postTrialPaywallShown,
          entitledToPro: entitledToPro,
          revenueCatAppUserId: revenueCatAppUserId,
          activeProductIds: activeProductIds,
          lastDeviceId: lastDeviceId,
        ),
      );
      final refreshed = await loadForUser(user);
      return refreshed ?? existing;
    }

    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final startMs = trialStartedAt.millisecondsSinceEpoch;
    final endsMs = startMs + trialDuration.inMilliseconds;
    final subscriberId = subscriberIdFor(user);
    final googleId = googleIdFor(user) ?? user.uid;
    final record = SubscriberAccessRecord(
      subscriberId: subscriberId,
      userId: user.uid,
      googleId: googleId,
      email: user.email,
      displayName: user.displayName,
      authProvider: 'google.com',
      trialStartedAtMs: startMs,
      trialEndsAtMs: endsMs,
      trialDurationMs: trialDuration.inMilliseconds,
      postTrialPaywallShown: postTrialPaywallShown,
      postTrialPaywallShownAtMs: postTrialPaywallShown ? nowMs : null,
      entitledToPro: entitledToPro,
      proEntitlementId: entitledToPro ? AppConfig.proEntitlementId : null,
      revenueCatAppUserId: revenueCatAppUserId,
      activeProductIds: activeProductIds,
      subscriptionStatus: _status(
        entitledToPro: entitledToPro,
        trialEndsAtMs: endsMs,
        nowMs: nowMs,
      ),
      platform: _platformLabel(),
      lastDeviceId: lastDeviceId,
      lastSyncedAtMs: nowMs,
      createdAtMs: nowMs,
      updatedAtMs: nowMs,
    );

    try {
      final batch = _db.batch();
      batch.set(
        _db.collection(subscribersCollection).doc(subscriberId),
        record.toFirestoreMap(),
      );
      batch.set(
        _db.collection(byUserIdCollection).doc(user.uid),
        {
          'userId': user.uid,
          'subscriberId': subscriberId,
          'googleId': googleId,
          'updatedAtMs': nowMs,
        },
      );
      await batch.commit();
    } catch (error, stack) {
      debugPrint('SubscriberAccessStore.ensureRecord create failed: $error\n$stack');
    }
    return record;
  }

  /// Updates mutable debug / entitlement fields without touching the trial
  /// clock. Safe under Firestore rules that freeze trialStartedAtMs.
  static Future<void> syncMutableFields(SubscriberAccessRecord record) async {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    final status = _status(
      entitledToPro: record.entitledToPro,
      trialEndsAtMs: record.trialEndsAtMs,
      nowMs: nowMs,
    );
    try {
      await _db.collection(subscribersCollection).doc(record.subscriberId).set(
        {
          'userId': record.userId,
          'email': record.email,
          'displayName': record.displayName,
          'authProvider': record.authProvider,
          'postTrialPaywallShown': record.postTrialPaywallShown,
          'postTrialPaywallShownAtMs': record.postTrialPaywallShownAtMs,
          'entitledToPro': record.entitledToPro,
          'proEntitlementId': record.entitledToPro
              ? (record.proEntitlementId ?? AppConfig.proEntitlementId)
              : record.proEntitlementId,
          'revenueCatAppUserId': record.revenueCatAppUserId,
          'activeProductIds': record.activeProductIds,
          'subscriptionStatus': status,
          'platform': record.platform ?? _platformLabel(),
          'lastDeviceId': record.lastDeviceId,
          'lastSyncedAtMs': nowMs,
          'updatedAtMs': nowMs,
          // Keep ends timestamp aligned with configured duration for display.
          'trialEndsAtMs': record.trialEndsAtMs,
        },
        SetOptions(merge: true),
      );
      await _db.collection(byUserIdCollection).doc(record.userId).set(
        {
          'userId': record.userId,
          'subscriberId': record.subscriberId,
          'googleId': record.googleId,
          'updatedAtMs': nowMs,
        },
        SetOptions(merge: true),
      );
    } catch (error, stack) {
      debugPrint('SubscriberAccessStore.syncMutableFields failed: $error\n$stack');
    }
  }

  static Future<void> markPostTrialPaywallShown(SubscriberAccessRecord record) {
    final nowMs = DateTime.now().millisecondsSinceEpoch;
    return syncMutableFields(
      record.copyWith(
        postTrialPaywallShown: true,
        postTrialPaywallShownAtMs: nowMs,
        updatedAtMs: nowMs,
      ),
    );
  }

  /// Local cache keys — keyed by Google subscriber id when known.
  static String localStartedAtKey(String accountKey) =>
      'one_one_free_trial_started_at_ms_$accountKey';

  static String localPaywallShownKey(String accountKey) =>
      'one_one_post_trial_paywall_shown_$accountKey';

  static String localSubscriberIdKey(String userId) =>
      'one_one_subscriber_id_$userId';

  static Future<void> cacheLocally({
    required String accountKey,
    required String userId,
    required DateTime trialStartedAt,
    required bool postTrialPaywallShown,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(
      localStartedAtKey(accountKey),
      trialStartedAt.millisecondsSinceEpoch,
    );
    await prefs.setBool(localPaywallShownKey(accountKey), postTrialPaywallShown);
    await prefs.setString(localSubscriberIdKey(userId), accountKey);
    // Keep legacy userId-keyed cache in sync for older installs.
    await prefs.setInt(
      localStartedAtKey(userId),
      trialStartedAt.millisecondsSinceEpoch,
    );
    await prefs.setBool(localPaywallShownKey(userId), postTrialPaywallShown);
  }

  static Future<({DateTime? startedAt, bool paywallShown})> readLocalCache({
    required String userId,
    String? subscriberId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String>[
      ?subscriberId,
      userId,
      if (prefs.getString(localSubscriberIdKey(userId)) case final cached?
          when cached.isNotEmpty)
        cached,
    ];

    DateTime? startedAt;
    var paywallShown = false;
    for (final key in keys) {
      final ms = prefs.getInt(localStartedAtKey(key));
      if (ms != null) {
        final candidate = DateTime.fromMillisecondsSinceEpoch(ms);
        if (startedAt == null || candidate.isBefore(startedAt)) {
          startedAt = candidate;
        }
      }
      paywallShown =
          paywallShown || (prefs.getBool(localPaywallShownKey(key)) ?? false);
    }
    return (startedAt: startedAt, paywallShown: paywallShown);
  }

  static Future<void> clearLocalCache({
    required String userId,
    String? subscriberId,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = <String>{
      userId,
      ?subscriberId,
      if (prefs.getString(localSubscriberIdKey(userId)) case final cached?
          when cached.isNotEmpty)
        cached,
    };
    for (final key in keys) {
      await prefs.remove(localStartedAtKey(key));
      await prefs.remove(localPaywallShownKey(key));
    }
    await prefs.remove(localSubscriberIdKey(userId));
  }

  static String _status({
    required bool entitledToPro,
    required int trialEndsAtMs,
    required int nowMs,
  }) {
    if (entitledToPro) return 'pro';
    if (nowMs < trialEndsAtMs) return 'trial';
    return 'free';
  }

  static String _platformLabel() {
    if (kIsWeb) return 'web';
    if (Platform.isIOS) return 'ios';
    if (Platform.isAndroid) return 'android';
    return Platform.operatingSystem;
  }
}
