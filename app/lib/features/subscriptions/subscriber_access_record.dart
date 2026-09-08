/// Firestore-backed subscriber / free-trial record (debugging + anti-abuse).
///
/// Document id is the stable Google account id when available; [userId] is
/// always the Firebase Auth uid for the signed-in session.
class SubscriberAccessRecord {
  const SubscriberAccessRecord({
    required this.subscriberId,
    required this.userId,
    required this.googleId,
    required this.trialStartedAtMs,
    required this.trialEndsAtMs,
    required this.trialDurationMs,
    required this.postTrialPaywallShown,
    required this.entitledToPro,
    required this.createdAtMs,
    required this.updatedAtMs,
    this.email,
    this.displayName,
    this.authProvider,
    this.postTrialPaywallShownAtMs,
    this.proEntitlementId,
    this.revenueCatAppUserId,
    this.activeProductIds = const [],
    this.subscriptionStatus,
    this.platform,
    this.lastDeviceId,
    this.lastSyncedAtMs,
  });

  final String subscriberId;
  final String userId;
  final String googleId;
  final int trialStartedAtMs;
  final int trialEndsAtMs;
  final int trialDurationMs;
  final bool postTrialPaywallShown;
  final bool entitledToPro;
  final int createdAtMs;
  final int updatedAtMs;
  final String? email;
  final String? displayName;
  final String? authProvider;
  final int? postTrialPaywallShownAtMs;
  final String? proEntitlementId;
  final String? revenueCatAppUserId;
  final List<String> activeProductIds;
  final String? subscriptionStatus;
  final String? platform;
  final String? lastDeviceId;
  final int? lastSyncedAtMs;

  DateTime get trialStartedAt =>
      DateTime.fromMillisecondsSinceEpoch(trialStartedAtMs);

  DateTime get trialEndsAt => DateTime.fromMillisecondsSinceEpoch(trialEndsAtMs);

  Map<String, Object?> toFirestoreMap() {
    return {
      'subscriberId': subscriberId,
      'userId': userId,
      'googleId': googleId,
      'email': email,
      'displayName': displayName,
      'authProvider': authProvider,
      'trialStartedAtMs': trialStartedAtMs,
      'trialEndsAtMs': trialEndsAtMs,
      'trialDurationMs': trialDurationMs,
      'postTrialPaywallShown': postTrialPaywallShown,
      'postTrialPaywallShownAtMs': postTrialPaywallShownAtMs,
      'entitledToPro': entitledToPro,
      'proEntitlementId': proEntitlementId,
      'revenueCatAppUserId': revenueCatAppUserId,
      'activeProductIds': activeProductIds,
      'subscriptionStatus': subscriptionStatus,
      'platform': platform,
      'lastDeviceId': lastDeviceId,
      'lastSyncedAtMs': lastSyncedAtMs,
      'createdAtMs': createdAtMs,
      'updatedAtMs': updatedAtMs,
    };
  }

  static SubscriberAccessRecord fromFirestoreMap(
    String subscriberId,
    Map<String, dynamic> data,
  ) {
    return SubscriberAccessRecord(
      subscriberId: data['subscriberId']?.toString() ?? subscriberId,
      userId: data['userId']?.toString() ?? '',
      googleId: data['googleId']?.toString() ?? '',
      email: data['email']?.toString(),
      displayName: data['displayName']?.toString(),
      authProvider: data['authProvider']?.toString(),
      trialStartedAtMs: _readInt(data['trialStartedAtMs']),
      trialEndsAtMs: _readInt(data['trialEndsAtMs']),
      trialDurationMs: _readInt(data['trialDurationMs']),
      postTrialPaywallShown: data['postTrialPaywallShown'] == true,
      postTrialPaywallShownAtMs: _readNullableInt(
        data['postTrialPaywallShownAtMs'],
      ),
      entitledToPro: data['entitledToPro'] == true,
      proEntitlementId: data['proEntitlementId']?.toString(),
      revenueCatAppUserId: data['revenueCatAppUserId']?.toString(),
      activeProductIds: _readStringList(data['activeProductIds']),
      subscriptionStatus: data['subscriptionStatus']?.toString(),
      platform: data['platform']?.toString(),
      lastDeviceId: data['lastDeviceId']?.toString(),
      lastSyncedAtMs: _readNullableInt(data['lastSyncedAtMs']),
      createdAtMs: _readInt(data['createdAtMs']),
      updatedAtMs: _readInt(data['updatedAtMs']),
    );
  }

  SubscriberAccessRecord copyWith({
    String? userId,
    String? email,
    String? displayName,
    String? authProvider,
    bool? postTrialPaywallShown,
    int? postTrialPaywallShownAtMs,
    bool? entitledToPro,
    String? proEntitlementId,
    String? revenueCatAppUserId,
    List<String>? activeProductIds,
    String? subscriptionStatus,
    String? platform,
    String? lastDeviceId,
    int? lastSyncedAtMs,
    int? updatedAtMs,
    int? trialEndsAtMs,
  }) {
    return SubscriberAccessRecord(
      subscriberId: subscriberId,
      userId: userId ?? this.userId,
      googleId: googleId,
      email: email ?? this.email,
      displayName: displayName ?? this.displayName,
      authProvider: authProvider ?? this.authProvider,
      trialStartedAtMs: trialStartedAtMs,
      trialEndsAtMs: trialEndsAtMs ?? this.trialEndsAtMs,
      trialDurationMs: trialDurationMs,
      postTrialPaywallShown:
          postTrialPaywallShown ?? this.postTrialPaywallShown,
      postTrialPaywallShownAtMs:
          postTrialPaywallShownAtMs ?? this.postTrialPaywallShownAtMs,
      entitledToPro: entitledToPro ?? this.entitledToPro,
      proEntitlementId: proEntitlementId ?? this.proEntitlementId,
      revenueCatAppUserId: revenueCatAppUserId ?? this.revenueCatAppUserId,
      activeProductIds: activeProductIds ?? this.activeProductIds,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      platform: platform ?? this.platform,
      lastDeviceId: lastDeviceId ?? this.lastDeviceId,
      lastSyncedAtMs: lastSyncedAtMs ?? this.lastSyncedAtMs,
      createdAtMs: createdAtMs,
      updatedAtMs: updatedAtMs ?? this.updatedAtMs,
    );
  }
}

int _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

int? _readNullableInt(Object? value) {
  if (value == null) return null;
  final parsed = _readInt(value);
  return parsed == 0 && value.toString() != '0' ? null : parsed;
}

List<String> _readStringList(Object? value) {
  if (value is! List) return const [];
  return value.map((item) => item.toString()).toList(growable: false);
}
