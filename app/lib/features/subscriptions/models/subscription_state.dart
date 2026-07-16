import 'subscription_tier.dart';

/// Immutable snapshot of the user's subscription status, resolved from
/// RevenueCat customer info and Firebase Remote Config.
class SubscriptionState {
  const SubscriptionState({
    required this.isSubscribed,
    required this.activeTier,
    required this.gracePeriodDays,
    this.expirationDate,
  });

  /// Whether the user has an active "OneOne Pro" entitlement.
  final bool isSubscribed;

  /// Which tier Remote Config dictates right now.
  final SubscriptionTier activeTier;

  /// How many days new free users get before the paywall blocks them when
  /// the extreme tier is active.
  final int gracePeriodDays;

  /// UTC timestamp (milliseconds since epoch) when the subscription expires,
  /// or null when not subscribed.
  final int? expirationDate;

  /// True when the extreme tier is active AND the user is not subscribed,
  /// meaning the paywall blocker should be shown (after grace period).
  bool get shouldBlock => !isSubscribed && activeTier == SubscriptionTier.extreme;
}
