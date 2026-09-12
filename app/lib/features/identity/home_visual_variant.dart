import 'package:one_one_app/one_one.dart';

// ---------------------------------------------------------------------------
// Enum — home screen backdrop variants (default collage vs illustrated).
// ---------------------------------------------------------------------------

enum HomeVisualVariant {
  /// Production look — blurred member collage.
  defaultLook(
    label: 'Default (current)',
    subtitle: 'Current home screen — member collage backdrop.',
    assetPath: null,
  ),

  /// Alternate illustrated doodle wallpaper (testing / fine-grained pick).
  screen1(
    label: 'Home screen 1',
    subtitle: 'Doodle backdrop. Same layout, top and bottom contrast scrims.',
    assetPath: 'assets/home_bg_images/home_bg_screen1.png',
  ),

  /// Illustrated doodle wallpaper 2 (canonical user-facing illustrated look).
  screen2(
    label: 'Home screen 2',
    subtitle: 'Alternate doodle backdrop. Same layout and controls.',
    assetPath: 'assets/home_bg_images/home_bg_screen2.png',
  );

  const HomeVisualVariant({
    required this.label,
    required this.subtitle,
    required this.assetPath,
  });

  final String label;
  final String subtitle;

  /// Bundled wallpaper for illustrated variants. Null for the default look.
  final String? assetPath;

  bool get usesDoodleBackdrop => assetPath != null;

  /// Whether this variant counts as the user-facing "Illustrated" option.
  bool get isIllustrated => usesDoodleBackdrop;
}

// ---------------------------------------------------------------------------
// Controller
// ---------------------------------------------------------------------------

/// Manages the active [HomeVisualVariant]. Persisted to SharedPreferences.
///
/// Users pick Default vs Illustrated in Settings. The hidden Testing section
/// (tap "Settings" title 7 times) still exposes screen1 vs screen2 for
/// fine-grained evaluation.
class HomeVisualVariantController {
  HomeVisualVariantController._();

  static const _prefKeyVariant = 'home_visual_variant';
  static const _prefKeyUnlocked = 'home_visual_testing_unlocked';

  /// Canonical illustrated wallpaper for the user-facing toggle.
  static const HomeVisualVariant illustratedLook = HomeVisualVariant.screen2;

  /// Whether the hidden testing section has been unlocked by the team.
  static final ValueNotifier<bool> unlocked = ValueNotifier<bool>(false);

  /// The currently active home screen visual variant.
  static final ValueNotifier<HomeVisualVariant> current =
      ValueNotifier<HomeVisualVariant>(HomeVisualVariant.defaultLook);

  /// Load persisted state. Call once on settings / home screen init.
  static Future<void> ensureLoaded() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_prefKeyVariant);
      if (raw != null) {
        final match = HomeVisualVariant.values
            .where((v) => v.name == raw)
            .firstOrNull;
        if (match != null) current.value = match;
      }
      unlocked.value = prefs.getBool(_prefKeyUnlocked) ?? false;
    } catch (_) {
      // Best-effort; defaults remain if prefs fail.
    }
  }

  /// Persist and apply a variant selection.
  static Future<void> setVariant(HomeVisualVariant variant) async {
    current.value = variant;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_prefKeyVariant, variant.name);
    } catch (_) {}
  }

  /// User-facing Default vs Illustrated toggle.
  ///
  /// Turning Illustrated on uses [illustratedLook] unless a doodle variant
  /// is already active (e.g. screen1 from Testing).
  static Future<void> setIllustrated(bool illustrated) async {
    if (illustrated) {
      if (!current.value.isIllustrated) {
        await setVariant(illustratedLook);
      }
    } else {
      await setVariant(HomeVisualVariant.defaultLook);
    }
  }

  /// Unlock the testing section. Called after the hidden tap sequence.
  static Future<void> unlockTesting() async {
    unlocked.value = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_prefKeyUnlocked, true);
    } catch (_) {}
  }
}
