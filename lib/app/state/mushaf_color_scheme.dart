import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/logging/logger.dart';
import 'theme_mode_provider.dart' show sharedPreferencesProvider;

const _storageKey = 'mushaf.color_scheme';

/// A mushaf colour style — one of the QPC V4 fonts' six `CPAL` palettes,
/// paired with the page background it is designed for.
///
/// Page mode and the Settings preview render the per-page font in the
/// selected style's [palette]; [darkPage] picks the page background (a dark
/// sheet for the white-text palettes, a light parchment for the others). The
/// style is the user's explicit choice — it is independent of the app's
/// light/dark theme. Replaces the `qcf`-era tajweed toggle.
enum MushafColorScheme {
  /// Full tajweed colouring on a light page (`CPAL` palette 0).
  tajweed('tajweed', 'Tajweed', palette: 0, darkPage: false),

  /// Full tajweed colouring on a dark page (`CPAL` palette 1).
  tajweedDark('tajweed_dark', 'Tajweed — dark', palette: 1, darkPage: true),

  /// Tajweed colouring, warmer shades, light page (`CPAL` palette 2).
  tajweedWarm('tajweed_warm', 'Tajweed — warm', palette: 2, darkPage: false),

  /// Plain single-colour text on a light page (`CPAL` palette 3).
  plain('plain', 'Plain', palette: 3, darkPage: false),

  /// Plain single-colour text on a dark page (`CPAL` palette 4).
  plainDark('plain_dark', 'Plain — dark', palette: 4, darkPage: true),

  /// Plain single-colour text, alternate marks, light page (`CPAL` palette 5).
  plainSoft('plain_soft', 'Plain — soft', palette: 5, darkPage: false);

  const MushafColorScheme(
    this.storageKey,
    this.label, {
    required this.palette,
    required this.darkPage,
  });

  /// Stable value persisted to `SharedPreferences`.
  final String storageKey;

  /// Short user-facing name.
  final String label;

  /// `CPAL` palette index (0..5) the per-page colour font renders in.
  final int palette;

  /// Whether the style is designed for a dark page background.
  final bool darkPage;

  /// Parses a stored value back to a style; falls back to [tajweed] for
  /// missing or unknown values — never throws.
  static MushafColorScheme fromStorage(String? raw) {
    for (final scheme in values) {
      if (scheme.storageKey == raw) return scheme;
    }
    return tajweed;
  }
}

/// Persists and exposes the user's mushaf colour-style choice.
class MushafColorSchemeController extends Notifier<MushafColorScheme> {
  @override
  MushafColorScheme build() {
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      return MushafColorScheme.fromStorage(prefs.getString(_storageKey));
    } catch (e) {
      appLogger.warning('Failed to read mushaf colour style: $e');
      return MushafColorScheme.tajweed;
    }
  }

  Future<void> select(MushafColorScheme scheme) async {
    if (state == scheme) return;
    state = scheme;
    try {
      final prefs = ref.read(sharedPreferencesProvider);
      final ok = await prefs.setString(_storageKey, scheme.storageKey);
      if (!ok) {
        appLogger.warning('Failed to persist mushaf colour style');
      }
    } catch (e) {
      appLogger.warning('Mushaf colour style persist threw: $e');
    }
  }
}

final mushafColorSchemeProvider =
    NotifierProvider<MushafColorSchemeController, MushafColorScheme>(
      MushafColorSchemeController.new,
    );
