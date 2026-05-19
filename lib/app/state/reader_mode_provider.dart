import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger.dart';
import 'reader_mode.dart';
import 'theme_mode_provider.dart' show sharedPreferencesProvider;

const _readerModeKey = 'reader.mode';

class ReaderModeController extends Notifier<ReaderMode> {
  @override
  ReaderMode build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      return ReaderMode.fromStorage(prefs.getString(_readerModeKey));
    } catch (e) {
      // Pref read failures must not crash the UI — fall back to default.
      appLogger.warning('Failed to read reader mode from prefs: $e');
      return ReaderMode.page;
    }
  }

  Future<void> setMode(ReaderMode mode) async {
    if (state == mode) return;
    state = mode;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final ok = await prefs.setString(_readerModeKey, mode.storageKey);
      if (!ok) {
        appLogger.warning('Failed to persist reader mode "${mode.storageKey}"');
      }
    } catch (e) {
      appLogger.warning('Reader mode persist threw: $e');
    }
  }
}

final readerModeProvider = NotifierProvider<ReaderModeController, ReaderMode>(
  ReaderModeController.new,
);
