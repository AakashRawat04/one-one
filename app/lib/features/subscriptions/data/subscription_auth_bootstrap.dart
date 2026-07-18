import 'package:shared_preferences/shared_preferences.dart';

/// Distinguishes an anonymous user created early for subscription identity
/// from a user who has explicitly entered or previously used the app.
class SubscriptionAuthBootstrap {
  static const String _pendingUserIdKey =
      'one_one_pending_subscription_bootstrap_user_id';

  static Future<void> markPending(
    SharedPreferences preferences,
    String userId,
  ) {
    return preferences.setString(_pendingUserIdKey, userId);
  }

  static bool isPending(SharedPreferences preferences, String userId) {
    return preferences.getString(_pendingUserIdKey) == userId;
  }

  static Future<void> clear(
    SharedPreferences preferences,
    String userId,
  ) async {
    if (isPending(preferences, userId)) {
      await preferences.remove(_pendingUserIdKey);
    }
  }
}
