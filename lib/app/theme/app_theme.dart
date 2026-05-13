import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:forui/forui.dart';

class AppTheme {
  const AppTheme._();

  // ForUI 0.20+ split each theme into a desktop/touch pair via
  // `FPlatformThemeData`. Quran Companion is desktop-first, so we always
  // resolve the desktop variant and let the future mobile push pick `.touch`.
  static FThemeData get light => FThemes.zinc.light.desktop;
  static FThemeData get dark => FThemes.zinc.dark.desktop;

  static FThemeData resolve(ThemeMode mode, Brightness platformBrightness) {
    return switch (mode) {
      ThemeMode.light => light,
      ThemeMode.dark => dark,
      ThemeMode.system => platformBrightness == Brightness.dark ? dark : light,
    };
  }
}
