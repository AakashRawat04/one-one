import 'package:flutter_test/flutter_test.dart';
import 'package:one_one_app/features/online/models/member_availability.dart';

void main() {
  group('MemberAvailability', () {
    test('live state is green while heartbeat is fresh', () {
      final availability = MemberAvailability.fromJson({
        'desiredState': 'online',
        'effectiveState': 'live',
        'canReceiveLiveAudio': true,
        'staleAfterAt': 130,
      });

      expect(availability.isLiveAt(100), isTrue);
    });

    test('away state never renders live', () {
      final availability = MemberAvailability.fromJson({
        'desiredState': 'away',
        'effectiveState': 'away',
        'canReceiveLiveAudio': false,
        'staleAfterAt': 130,
      });

      expect(availability.isLiveAt(100), isFalse);
    });

    test('contradictory away records do not render live', () {
      final availability = MemberAvailability.fromJson({
        'desiredState': 'away',
        'effectiveState': 'live',
        'canReceiveLiveAudio': true,
        'staleAfterAt': 130,
      });

      expect(availability.isLiveAt(100), isFalse);
    });

    test('stale live heartbeat no longer renders live', () {
      final availability = MemberAvailability.fromJson({
        'desiredState': 'online',
        'effectiveState': 'live',
        'canReceiveLiveAudio': true,
        'staleAfterAt': 100,
      });

      expect(availability.isLiveAt(100), isFalse);
      expect(availability.isLiveAt(101), isFalse);
    });

    test('connecting state does not render live', () {
      const availability = MemberAvailability(
        desiredState: 'online',
        effectiveState: 'connecting',
        canReceiveLiveAudio: false,
      );

      expect(availability.isLiveAt(100), isFalse);
    });
  });
}
