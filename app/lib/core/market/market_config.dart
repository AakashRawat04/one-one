import 'package:one_one_app/one_one.dart';

/// Centralized per-market product configuration.
///
/// Screens should read flags and variants from here instead of scattering
/// `if (market == Market.germany)` through unrelated widgets.
class MarketConfig {
  const MarketConfig({
    required this.market,
    required this.onboardingVariant,
    required this.supportedLanguages,
    required this.defaultLanguage,
  });

  final Market market;
  final OnboardingVariant onboardingVariant;
  final List<AppLanguage> supportedLanguages;
  final AppLanguage defaultLanguage;

  /// Phase 1: UK, US, and India are English-only. Other launched markets
  /// offer English plus the Play-listing language.
  bool get offersLanguageChoice => supportedLanguages.length > 1;

  String get defaultLocaleTag => localeTagFor(defaultLanguage);

  String localeTagFor(AppLanguage language) {
    if (market == Market.unknown) return language.languageCode;
    return '${language.languageCode}-${market.isoCode}';
  }

  bool supports(AppLanguage language) => supportedLanguages.contains(language);

  AppLanguage coerce(AppLanguage language) {
    return supports(language) ? language : defaultLanguage;
  }

  MarketConfig copyWith({OnboardingVariant? onboardingVariant}) {
    return MarketConfig(
      market: market,
      onboardingVariant: onboardingVariant ?? this.onboardingVariant,
      supportedLanguages: supportedLanguages,
      defaultLanguage: defaultLanguage,
    );
  }

  /// Built-in defaults. Remote Config may override [onboardingVariant] only.
  static MarketConfig defaultsFor(Market market) {
    return switch (market) {
      Market.india => const MarketConfig(
        market: Market.india,
        onboardingVariant: OnboardingVariant.india,
        supportedLanguages: [AppLanguage.english],
        defaultLanguage: AppLanguage.english,
      ),
      Market.usa => const MarketConfig(
        market: Market.usa,
        onboardingVariant: OnboardingVariant.usa,
        supportedLanguages: [AppLanguage.english],
        defaultLanguage: AppLanguage.english,
      ),
      Market.unitedKingdom => const MarketConfig(
        market: Market.unitedKingdom,
        onboardingVariant: OnboardingVariant.unitedKingdom,
        supportedLanguages: [AppLanguage.english],
        defaultLanguage: AppLanguage.english,
      ),
      Market.germany => const MarketConfig(
        market: Market.germany,
        onboardingVariant: OnboardingVariant.germany,
        supportedLanguages: [AppLanguage.english, AppLanguage.german],
        defaultLanguage: AppLanguage.german,
      ),
      Market.france => const MarketConfig(
        market: Market.france,
        onboardingVariant: OnboardingVariant.france,
        supportedLanguages: [AppLanguage.english, AppLanguage.french],
        defaultLanguage: AppLanguage.french,
      ),
      Market.spain => const MarketConfig(
        market: Market.spain,
        onboardingVariant: OnboardingVariant.spain,
        supportedLanguages: [AppLanguage.english, AppLanguage.spanish],
        defaultLanguage: AppLanguage.spanish,
      ),
      Market.italy => const MarketConfig(
        market: Market.italy,
        onboardingVariant: OnboardingVariant.italy,
        supportedLanguages: [AppLanguage.english, AppLanguage.italian],
        defaultLanguage: AppLanguage.italian,
      ),
      Market.unknown => const MarketConfig(
        market: Market.unknown,
        onboardingVariant: OnboardingVariant.defaultVariant,
        supportedLanguages: [AppLanguage.english],
        defaultLanguage: AppLanguage.english,
      ),
    };
  }

  /// Applies a Remote Config variant id when one is present and recognized.
  static MarketConfig resolve(
    Market market, {
    String? remoteOnboardingVariant,
  }) {
    final defaults = defaultsFor(market);
    final parsed = OnboardingVariant.tryParse(remoteOnboardingVariant);
    if (parsed == null) return defaults;
    return defaults.copyWith(onboardingVariant: parsed);
  }
}

/// Resolved market plus the evidence used to pick it. Safe to log.
class MarketSnapshot {
  const MarketSnapshot({
    required this.market,
    required this.source,
    this.isoCountryCode,
  });

  final Market market;
  final MarketSource source;
  final String? isoCountryCode;

  MarketConfig get config => MarketConfig.resolve(
    market,
    remoteOnboardingVariant: MarketRemoteConfig.onboardingVariantOrNull(),
  );

  /// India keeps the local onboarding illustrations. Any other resolved
  /// Play/backend country (including storefronts without a [Market] enum
  /// value yet) uses the abroad artwork set.
  bool get usesAbroadOnboardingArt {
    if (market == Market.india) return false;
    final iso = isoCountryCode?.trim().toUpperCase();
    if (iso == 'IN') return false;
    if (market != Market.unknown) return true;
    return iso != null && iso.isNotEmpty && iso != 'XX';
  }

  /// Third permission-setup screen artwork (background / battery step).
  String get permissionSetupScreen3Asset => usesAbroadOnboardingArt
      ? 'assets/abroad_onboarding3.png'
      : 'assets/Onboarding2.png';

  static const unknown = MarketSnapshot(
    market: Market.unknown,
    source: MarketSource.unknown,
  );

  MarketSnapshot copyWith({
    Market? market,
    MarketSource? source,
    String? isoCountryCode,
  }) {
    return MarketSnapshot(
      market: market ?? this.market,
      source: source ?? this.source,
      isoCountryCode: isoCountryCode ?? this.isoCountryCode,
    );
  }
}

/// Reads already-fetched Remote Config. Never blocks startup; empty/missing
/// values keep the compiled [MarketConfig] defaults.
abstract final class MarketRemoteConfig {
  static const onboardingVariantKey = 'onboarding_variant';

  static String? onboardingVariantOrNull() {
    if (Firebase.apps.isEmpty) return null;
    try {
      final value = FirebaseRemoteConfig.instance
          .getString(onboardingVariantKey)
          .trim();
      return value.isEmpty ? null : value;
    } catch (_) {
      return null;
    }
  }
}
