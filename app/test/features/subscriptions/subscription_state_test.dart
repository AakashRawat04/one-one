import 'package:flutter_test/flutter_test.dart';
import 'package:one_one_app/features/subscriptions/models/subscription_state.dart';
import 'package:one_one_app/features/subscriptions/models/subscription_tier.dart';

SubscriptionState state({
  bool subscribed = false,
  bool developer = false,
  bool hardPaywall = false,
  SubscriptionTier tier = SubscriptionTier.extreme,
  int? graceEndsAt = 1000,
}) {
  return SubscriptionState(
    isSubscribed: subscribed,
    hasDeveloperBypass: developer,
    activeTier: tier,
    gracePeriodDays: 7,
    developerRedeemEnabled: true,
    requiresImmediateSubscription: hardPaywall,
    graceEndsAt: graceEndsAt,
  );
}

void main() {
  test('normal tier never blocks free users', () {
    expect(state(tier: SubscriptionTier.normal).shouldBlockAt(5000), isFalse);
  });

  test('public hard paywall blocks regardless of pricing tier', () {
    expect(
      state(
        tier: SubscriptionTier.normal,
        hardPaywall: true,
      ).shouldBlockAt(0),
      isTrue,
    );
  });

  test('public hard paywall never honors a developer claim', () {
    expect(
      state(
        developer: true,
        hardPaywall: true,
      ).shouldBlockAt(0),
      isTrue,
    );
  });

  test('extreme tier blocks only after grace deadline', () {
    final subject = state(graceEndsAt: 1000);
    expect(subject.shouldBlockAt(999), isFalse);
    expect(subject.shouldBlockAt(1000), isTrue);
  });

  test('subscription and developer claim independently bypass blocker', () {
    expect(state(subscribed: true).shouldBlockAt(5000), isFalse);
    expect(state(developer: true).shouldBlockAt(5000), isFalse);
  });

  test('missing rollout start fails open instead of blocking immediately', () {
    expect(state(graceEndsAt: null).shouldBlockAt(5000), isFalse);
  });
}
