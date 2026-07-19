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
    required this.requiresImmediateSubscription,
    this.graceEndsAt,
    this.expirationDate,
  });

  /// Whether the user has an active "OneOne Pro" entitlement.
  final bool isSubscribed;

  /// Server-verified team claim, honored only by internal binaries.
  final bool hasDeveloperBypass;

  /// Which tier Remote Config dictates right now.
  final SubscriptionTier activeTier;

  /// Internal-build grace setting used before the extreme-tier blocker.
  final int gracePeriodDays;

  /// Whether the developer-code entry point should be visible on the blocker.
  final bool developerRedeemEnabled;

  /// Public/store binaries set this so the entitlement is always a hard gate.
  /// Internal binaries keep the configurable extreme-tier trial window.
  final bool requiresImmediateSubscription;

  /// UTC timestamp (milliseconds since epoch) when extreme-tier enforcement
  /// begins for this rollout. Null means the grace window has not started.
  final int? graceEndsAt;

  /// UTC timestamp (milliseconds since epoch) when the subscription expires,
  /// or null when not subscribed.
  final int? expirationDate;

  bool shouldBlockAt(int nowMs) {
    if (isSubscribed) return false;
    if (hasDeveloperBypass && !requiresImmediateSubscription) return false;
    if (requiresImmediateSubscription) return true;
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
    bool? requiresImmediateSubscription,
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
      requiresImmediateSubscription:
          requiresImmediateSubscription ?? this.requiresImmediateSubscription,
      graceEndsAt: graceEndsAt ?? this.graceEndsAt,
      expirationDate: expirationDate ?? this.expirationDate,
    );
  }
}
