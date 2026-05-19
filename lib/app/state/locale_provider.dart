import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger.dart';
import 'theme_mode_provider.dart' show sharedPreferencesProvider;

const _localeKey = 'app.locale';

/// The user's interface-language choice. [system] follows the OS locale;
/// [english] and [arabic] pin a specific locale.
enum AppLocaleOption {
  system,
  english,
  arabic;

  /// The [Locale] to hand `MaterialApp`, or `null` to follow the platform.
  Locale? get locale => switch (this) {
    AppLocaleOption.system => null,
    AppLocaleOption.english => const Locale('en'),
    AppLocaleOption.arabic => const Locale('ar'),
  };
}

/// Holds the interface-language choice and persists it across restarts.
///
/// Mirrors [ThemeModeController] in `theme_mode_provider.dart`: a [Notifier]
/// seeded from `SharedPreferences`, writing the choice back on every change.
class LocaleController extends Notifier<AppLocaleOption> {
  @override
  AppLocaleOption build() {
    final prefs = ref.read(sharedPreferencesProvider);
    final stored = prefs.getString(_localeKey);
    if (stored == null) return AppLocaleOption.system;
    return AppLocaleOption.values.firstWhere(
      (o) => o.name == stored,
      orElse: () => AppLocaleOption.system,
    );
  }

  Future<void> setOption(AppLocaleOption option) async {
    if (state == option) return;
    state = option;
    final prefs = ref.read(sharedPreferencesProvider);
    final ok = await prefs.setString(_localeKey, option.name);
    if (!ok) {
      appLogger.warning('Failed to persist locale option "${option.name}"');
    }
  }
}

final localeProvider = NotifierProvider<LocaleController, AppLocaleOption>(
  LocaleController.new,
);
