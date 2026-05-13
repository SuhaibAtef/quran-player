import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger.dart';
import 'theme_mode_provider.dart' show sharedPreferencesProvider;

const _tajweedKey = 'reader.tajweed_enabled';

/// Whether the page-mode mushaf renderer should colour the text with the
/// `qcf_quran_plus` tajweed glyphs. Only the page-mode reader honours this —
/// text mode renders plain Tanzil text and has no tajweed concept.
class TajweedController extends Notifier<bool> {
  @override
  bool build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      return prefs.getBool(_tajweedKey) ?? false;
    } catch (e) {
      appLogger.warning('Failed to read tajweed pref: $e');
      return false;
    }
  }

  Future<void> setEnabled(bool enabled) async {
    if (state == enabled) return;
    state = enabled;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final ok = await prefs.setBool(_tajweedKey, enabled);
      if (!ok) {
        appLogger.warning('Failed to persist tajweed pref ($enabled)');
      }
    } catch (e) {
      appLogger.warning('Tajweed pref persist threw: $e');
    }
  }
}

final tajweedEnabledProvider = NotifierProvider<TajweedController, bool>(
  TajweedController.new,
);
