import 'package:flutter/material.dart' show Brightness, ThemeMode;
import 'package:forui/forui.dart';

class AppTheme {
  const AppTheme._();

  static FThemeData get light => FThemes.zinc.light;
  static FThemeData get dark => FThemes.zinc.dark;

  static FThemeData resolve(ThemeMode mode, Brightness platformBrightness) {
    return switch (mode) {
      ThemeMode.light => light,
      ThemeMode.dark => dark,
      ThemeMode.system => platformBrightness == Brightness.dark ? dark : light,
    };
  }
}
