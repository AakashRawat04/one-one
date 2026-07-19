import 'package:flutter_test/flutter_test.dart';
import 'package:one_one_app/features/subscriptions/data/subscription_grace_period_store.dart';
import 'package:one_one_app/features/subscriptions/models/subscription_tier.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  const dayMs = Duration.millisecondsPerDay;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('uses shared Remote Config rollout timestamp when supplied', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SubscriptionGracePeriodStore(
      preferences: prefs,
      nowMs: () => 9000,
    );

    final result = await store.resolveGraceEndsAt(
      tier: SubscriptionTier.extreme,
      gracePeriodDays: 14,
      remoteExtremeActivatedAtMs: 1000,
    );

    expect(result, 1000 + 14 * dayMs);
  });

  test('supports an internal short trial duration without changing public days', () async {
    final prefs = await SharedPreferences.getInstance();
    final store = SubscriptionGracePeriodStore(
      preferences: prefs,
      nowMs: () => 9000,
    );

    final result = await store.resolveGraceEndsAt(
      tier: SubscriptionTier.extreme,
      gracePeriodDays: 7,
      remoteExtremeActivatedAtMs: 1000,
      graceDuration: const Duration(hours: 6),
    );

    expect(result, 1000 + const Duration(hours: 6).inMilliseconds);
  });

  test(
    'persists first local observation when rollout timestamp is absent',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var now = 2000;
      final store = SubscriptionGracePeriodStore(
        preferences: prefs,
        nowMs: () => now,
      );

      final first = await store.resolveGraceEndsAt(
        tier: SubscriptionTier.extreme,
        gracePeriodDays: 7,
        remoteExtremeActivatedAtMs: null,
      );
      now = 9000;
      final second = await store.resolveGraceEndsAt(
        tier: SubscriptionTier.extreme,
        gracePeriodDays: 7,
        remoteExtremeActivatedAtMs: null,
      );

      expect(first, 2000 + 7 * dayMs);
      expect(second, first);
    },
  );

  test(
    'normal tier resets local transition for a future extreme rollout',
    () async {
      final prefs = await SharedPreferences.getInstance();
      var now = 2000;
      final store = SubscriptionGracePeriodStore(
        preferences: prefs,
        nowMs: () => now,
      );
      await store.resolveGraceEndsAt(
        tier: SubscriptionTier.extreme,
        gracePeriodDays: 7,
        remoteExtremeActivatedAtMs: null,
      );
      await store.resolveGraceEndsAt(
        tier: SubscriptionTier.normal,
        gracePeriodDays: 7,
        remoteExtremeActivatedAtMs: null,
      );
      now = 8000;

      final nextRollout = await store.resolveGraceEndsAt(
        tier: SubscriptionTier.extreme,
        gracePeriodDays: 7,
        remoteExtremeActivatedAtMs: null,
      );
      expect(nextRollout, 8000 + 7 * dayMs);
    },
  );
}
