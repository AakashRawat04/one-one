import 'package:flutter_test/flutter_test.dart';

import 'package:one_one_app/one_one.dart';

void main() {
  group('Market.fromIsoCode', () {
    test('maps Phase 1 Play countries', () {
      expect(Market.fromIsoCode('IN'), Market.india);
      expect(Market.fromIsoCode('us'), Market.usa);
      expect(Market.fromIsoCode('GB'), Market.unitedKingdom);
      expect(Market.fromIsoCode('UK'), Market.unitedKingdom);
      expect(Market.fromIsoCode('DE'), Market.germany);
      expect(Market.fromIsoCode('FR'), Market.france);
      expect(Market.fromIsoCode('ES'), Market.spain);
      expect(Market.fromIsoCode('IT'), Market.italy);
    });

    test('unknown codes and empty values fall back', () {
      expect(Market.fromIsoCode(null), Market.unknown);
      expect(Market.fromIsoCode(''), Market.unknown);
      expect(Market.fromIsoCode('BR'), Market.unknown);
    });
  });

  group('MarketConfig language policy', () {
    test('UK, US, and India are English-only', () {
      for (final market in [Market.india, Market.usa, Market.unitedKingdom]) {
        final config = MarketConfig.defaultsFor(market);
        expect(config.offersLanguageChoice, isFalse);
        expect(config.supportedLanguages, [AppLanguage.english]);
      }
    });

    test('France, Spain, Germany, and Italy are bilingual', () {
      expect(MarketConfig.defaultsFor(Market.france).supportedLanguages, [
        AppLanguage.english,
        AppLanguage.french,
      ]);
      expect(MarketConfig.defaultsFor(Market.spain).supportedLanguages, [
        AppLanguage.english,
        AppLanguage.spanish,
      ]);
      expect(MarketConfig.defaultsFor(Market.germany).supportedLanguages, [
        AppLanguage.english,
        AppLanguage.german,
      ]);
      expect(MarketConfig.defaultsFor(Market.italy).supportedLanguages, [
        AppLanguage.english,
        AppLanguage.italian,
      ]);
      expect(
        MarketConfig.defaultsFor(Market.germany).offersLanguageChoice,
        isTrue,
      );
    });

    test('language pickers expose a country flag', () {
      expect(AppLanguage.english.flagEmoji, '🇬🇧');
      expect(AppLanguage.french.flagEmoji, '🇫🇷');
      expect(AppLanguage.spanish.flagEmoji, '🇪🇸');
      expect(AppLanguage.german.flagEmoji, '🇩🇪');
      expect(AppLanguage.italian.flagEmoji, '🇮🇹');
    });

    test('unsupported locale falls back to the market default', () {
      expect(
        MarketConfig.defaultsFor(Market.usa).coerce(AppLanguage.french),
        AppLanguage.english,
      );
      expect(
        MarketConfig.defaultsFor(Market.germany).coerce(AppLanguage.french),
        AppLanguage.german,
      );
    });

    test('locale tags keep market independent of language', () {
      expect(
        MarketConfig.defaultsFor(
          Market.germany,
        ).localeTagFor(AppLanguage.english),
        'en-DE',
      );
      expect(
        MarketConfig.defaultsFor(Market.usa).localeTagFor(AppLanguage.spanish),
        'es-US',
      );
    });

    test('Remote Config can select an already-built onboarding variant', () {
      final config = MarketConfig.resolve(
        Market.germany,
        remoteOnboardingVariant: 'germany_v1',
      );
      expect(config.onboardingVariant, OnboardingVariant.germany);
      expect(
        MarketConfig.resolve(
          Market.india,
          remoteOnboardingVariant: 'not_a_variant',
        ).onboardingVariant,
        OnboardingVariant.india,
      );
    });
  });

  group('MarketSnapshot onboarding artwork', () {
    test('India keeps the local screen-3 illustration', () {
      const snapshot = MarketSnapshot(
        market: Market.india,
        source: MarketSource.playStore,
        isoCountryCode: 'IN',
      );
      expect(snapshot.usesAbroadOnboardingArt, isFalse);
      expect(snapshot.permissionSetupScreen3Asset, 'assets/Onboarding2.png');
    });

    test('Play markets outside India use abroad_onboarding3', () {
      const snapshot = MarketSnapshot(
        market: Market.usa,
        source: MarketSource.playStore,
        isoCountryCode: 'US',
      );
      expect(snapshot.usesAbroadOnboardingArt, isTrue);
      expect(
        snapshot.permissionSetupScreen3Asset,
        'assets/abroad_onboarding3.png',
      );
    });

    test('unmapped Play storefronts still get abroad artwork', () {
      const snapshot = MarketSnapshot(
        market: Market.unknown,
        source: MarketSource.playStore,
        isoCountryCode: 'AU',
      );
      expect(snapshot.usesAbroadOnboardingArt, isTrue);
      expect(
        snapshot.permissionSetupScreen3Asset,
        'assets/abroad_onboarding3.png',
      );
    });

    test('unresolved market keeps the India illustration', () {
      expect(MarketSnapshot.unknown.usesAbroadOnboardingArt, isFalse);
      expect(
        MarketSnapshot.unknown.permissionSetupScreen3Asset,
        'assets/Onboarding2.png',
      );
    });
  });

  group('MarketResolver', () {
    test('prefers backend over Play and device region', () async {
      final resolver = MarketResolver(
        readDebugOverride: () async => null,
        readBackendMarket: () async => 'DE',
        readPlayCountry: () async => 'US',
        readDeviceRegion: () => 'IN',
      );
      final snapshot = await resolver.resolve();
      expect(snapshot.market, Market.germany);
      expect(snapshot.source, MarketSource.backend);
    });

    test('uses Play storefront when the account has no market', () async {
      final resolver = MarketResolver(
        readDebugOverride: () async => null,
        readBackendMarket: () async => null,
        readPlayCountry: () async => 'FR',
        readDeviceRegion: () => 'US',
      );
      final snapshot = await resolver.resolve();
      expect(snapshot.market, Market.france);
      expect(snapshot.source, MarketSource.playStore);
    });

    test('does not let device region override a cached Play market', () async {
      final resolver = MarketResolver(
        readDebugOverride: () async => null,
        readBackendMarket: () async => null,
        readPlayCountry: () async => null,
        readDeviceRegion: () => 'IN',
      );
      final snapshot = await resolver.resolve(
        cached: const MarketSnapshot(
          market: Market.germany,
          source: MarketSource.playStore,
          isoCountryCode: 'DE',
        ),
      );
      expect(snapshot.market, Market.germany);
      expect(snapshot.source, MarketSource.cache);
    });

    test('falls back to device region then unknown', () async {
      final deviceResolver = MarketResolver(
        readDebugOverride: () async => null,
        readBackendMarket: () async => null,
        readPlayCountry: () async => null,
        readDeviceRegion: () => 'ES',
      );
      final device = await deviceResolver.resolve();
      expect(device.market, Market.spain);
      expect(device.source, MarketSource.deviceRegion);

      final unknownResolver = MarketResolver(
        readDebugOverride: () async => null,
        readBackendMarket: () async => null,
        readPlayCountry: () async => null,
        readDeviceRegion: () => null,
      );
      final unknown = await unknownResolver.resolve();
      expect(unknown.market, Market.unknown);
      expect(unknown.source, MarketSource.unknown);
    });

    test('debug override wins in debug builds', () async {
      final resolver = MarketResolver(
        readDebugOverride: () async => Market.italy,
        readBackendMarket: () async => 'DE',
        readPlayCountry: () async => 'US',
        readDeviceRegion: () => 'IN',
      );
      final snapshot = await resolver.resolve();
      if (kDebugMode) {
        expect(snapshot.market, Market.italy);
        expect(snapshot.source, MarketSource.debugOverride);
      }
    });
  });

  group('AppLanguage', () {
    test('parses language codes and ignores region', () {
      expect(AppLanguage.fromLanguageCode('fr-FR'), AppLanguage.french);
      expect(AppLanguage.fromLanguageCode('de_DE'), AppLanguage.german);
      expect(AppLanguage.fromLanguageCode('pt'), AppLanguage.english);
    });
  });
}
