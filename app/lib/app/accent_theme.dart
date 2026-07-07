import 'package:flutter/material.dart';

class AccentOption {
  const AccentOption({
    required this.key,
    required this.label,
    required this.color,
  });

  final String key;
  final String label;
  final Color color;
}

const List<AccentOption> accentOptions = [
  AccentOption(key: 'coral', label: 'Coral', color: Color(0xffff5a5f)),
  AccentOption(key: 'lime', label: 'Lime', color: Color(0xff9bdc28)),
  AccentOption(key: 'sky', label: 'Sky', color: Color(0xff25a9ff)),
  AccentOption(key: 'violet', label: 'Violet', color: Color(0xff8b5cf6)),
  AccentOption(key: 'amber', label: 'Amber', color: Color(0xffffb020)),
  AccentOption(key: 'pink', label: 'Pink', color: Color(0xffec4899)),
  AccentOption(key: 'teal', label: 'Teal', color: Color(0xff00b8a9)),
];

Color accentColorForKey(String key) {
  for (final option in accentOptions) {
    if (option.key == key) return option.color;
  }

  return accentOptions.first.color;
}

class AccentThemeController {
  AccentThemeController._();

  static final ValueNotifier<String> accentKey = ValueNotifier<String>(
    accentOptions.first.key,
  );

  static void setAccentKey(String key) {
    accentKey.value = accentOptions.any((option) => option.key == key)
        ? key
        : accentOptions.first.key;
  }
}
