import 'package:flutter_test/flutter_test.dart';
import 'package:one_one_app/features/subscriptions/data/subscription_auth_bootstrap.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('tracks only the subscription-created pending Firebase user', () async {
    final prefs = await SharedPreferences.getInstance();
    await SubscriptionAuthBootstrap.markPending(prefs, 'pending-user');

    expect(SubscriptionAuthBootstrap.isPending(prefs, 'pending-user'), isTrue);
    expect(SubscriptionAuthBootstrap.isPending(prefs, 'other-user'), isFalse);
  });

  test('clears marker after explicit onboarding', () async {
    final prefs = await SharedPreferences.getInstance();
    await SubscriptionAuthBootstrap.markPending(prefs, 'pending-user');
    await SubscriptionAuthBootstrap.clear(prefs, 'pending-user');

    expect(SubscriptionAuthBootstrap.isPending(prefs, 'pending-user'), isFalse);
  });
}
