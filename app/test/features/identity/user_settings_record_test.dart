import 'package:flutter_test/flutter_test.dart';

import 'package:one_one_app/one_one.dart';

void main() {
  group('HapticsIntensity', () {
    test('defaults to light for missing or unknown values', () {
      expect(HapticsIntensity.parse(null), HapticsIntensity.light);
      expect(HapticsIntensity.parse(''), HapticsIntensity.light);
      expect(HapticsIntensity.parse('off'), HapticsIntensity.light);
    });

    test('parses the three shipped tiers', () {
      expect(HapticsIntensity.parse('light'), HapticsIntensity.light);
      expect(HapticsIntensity.parse('medium'), HapticsIntensity.medium);
      expect(HapticsIntensity.parse('wild'), HapticsIntensity.wild);
    });
  });

  group('UserSettingsRecord haptics', () {
    test('defaults to light for new users', () {
      final settings = UserSettingsRecord.defaults(1);
      expect(settings.hapticsIntensity, HapticsIntensity.light);
      expect(settings.hapticsEnabled, isTrue);
    });

    test(
      'reads hapticsIntensity from json and ignores legacy false toggle',
      () {
        final settings = UserSettingsRecord.fromJson({
          'accentColorKey': 'coral',
          'hapticsEnabled': false,
          'hapticsIntensity': 'wild',
          'audioOutputPreference': 'earpiece',
          'updatedAt': 10,
        });
        expect(settings.hapticsIntensity, HapticsIntensity.wild);
        expect(settings.hapticsEnabled, isTrue);
      },
    );

    test('legacy records without intensity stay on light', () {
      final settings = UserSettingsRecord.fromJson({
        'accentColorKey': 'coral',
        'hapticsEnabled': true,
        'updatedAt': 10,
      });
      expect(settings.hapticsIntensity, HapticsIntensity.light);
    });

    test('preferredLocale round-trips when present', () {
      final settings = UserSettingsRecord.fromJson({
        'accentColorKey': 'coral',
        'preferredLocale': 'de',
        'updatedAt': 10,
      });
      expect(settings.preferredLocale, 'de');
      expect(settings.toJson()['preferredLocale'], 'de');
    });
  });

  group('HomeVisualVariant', () {
    test('ships default plus two doodle backdrops', () {
      expect(HomeVisualVariant.values, hasLength(3));
      expect(HomeVisualVariant.defaultLook.usesDoodleBackdrop, isFalse);
      expect(
        HomeVisualVariant.screen1.assetPath,
        'assets/home_bg_images/home_bg_screen1.png',
      );
      expect(
        HomeVisualVariant.screen2.assetPath,
        'assets/home_bg_images/home_bg_screen2.png',
      );
      expect(HomeVisualVariant.screen1.usesDoodleBackdrop, isTrue);
      expect(HomeVisualVariant.screen2.usesDoodleBackdrop, isTrue);
      expect(HomeVisualVariantController.illustratedLook, HomeVisualVariant.screen2);
    });
  });
}
