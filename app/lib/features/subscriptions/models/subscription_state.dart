import 'subscription_tier.dart';

/// Immutable snapshot of the user's subscription status, resolved from
/// RevenueCat customer info and Firebase Remote Config.
class SubscriptionState {
  const SubscriptionState({
    required this.isSubscribed,
    required this.hasDeveloperBypass,
    required this.activeTier,
    required this.gracePeriodDays,
    required this.developerRedeemEnabled,
    this.graceEndsAt,
    this.expirationDate,
  });

  /// Whether the user has an active "OneOne Pro" entitlement.
  final bool isSubscribed;

  /// Server-verified Firebase custom claim granted to approved team accounts.
  final bool hasDeveloperBypass;

  /// Which tier Remote Config dictates right now.
  final SubscriptionTier activeTier;

  /// How many days new free users get before the paywall blocks them when
  /// the extreme tier is active.
  final int gracePeriodDays;

  /// Whether the developer-code entry point should be visible on the blocker.
  final bool developerRedeemEnabled;

  /// UTC timestamp (milliseconds since epoch) when extreme-tier enforcement
  /// begins for this rollout. Null means the grace window has not started.
  final int? graceEndsAt;

  /// UTC timestamp (milliseconds since epoch) when the subscription expires,
  /// or null when not subscribed.
  final int? expirationDate;

  bool shouldBlockAt(int nowMs) {
    if (isSubscribed || hasDeveloperBypass) return false;
    if (activeTier != SubscriptionTier.extreme) return false;
    final graceEnd = graceEndsAt;
    return graceEnd != null && nowMs >= graceEnd;
  }

  bool get shouldBlock => shouldBlockAt(DateTime.now().millisecondsSinceEpoch);

  SubscriptionState copyWith({
    bool? isSubscribed,
    bool? hasDeveloperBypass,
    SubscriptionTier? activeTier,
    int? gracePeriodDays,
    bool? developerRedeemEnabled,
    int? graceEndsAt,
    int? expirationDate,
  }) {
    return SubscriptionState(
      isSubscribed: isSubscribed ?? this.isSubscribed,
      hasDeveloperBypass: hasDeveloperBypass ?? this.hasDeveloperBypass,
      activeTier: activeTier ?? this.activeTier,
      gracePeriodDays: gracePeriodDays ?? this.gracePeriodDays,
      developerRedeemEnabled:
          developerRedeemEnabled ?? this.developerRedeemEnabled,
      graceEndsAt: graceEndsAt ?? this.graceEndsAt,
      expirationDate: expirationDate ?? this.expirationDate,
    );
  }
}
