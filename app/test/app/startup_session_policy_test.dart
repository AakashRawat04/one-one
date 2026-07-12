import 'package:flutter_test/flutter_test.dart';
import 'package:one_one_app/app/startup_session_policy.dart';

void main() {
  group('StartupSessionPolicy', () {
    test('resumes when Firebase restored the user initially', () {
      expect(
        StartupSessionPolicy.shouldResume(
          hadInitialFirebaseUser: true,
          hasCurrentFirebaseUser: false,
        ),
        isTrue,
      );
    });

    test('resumes when Firebase restoration completes during the splash', () {
      expect(
        StartupSessionPolicy.shouldResume(
          hadInitialFirebaseUser: false,
          hasCurrentFirebaseUser: true,
        ),
        isTrue,
      );
    });

    test('shows first-run entry without a restored Firebase credential', () {
      expect(
        StartupSessionPolicy.shouldResume(
          hadInitialFirebaseUser: false,
          hasCurrentFirebaseUser: false,
        ),
        isFalse,
      );
    });
  });
}
