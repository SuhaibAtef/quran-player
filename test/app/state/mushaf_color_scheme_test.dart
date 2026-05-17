import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/state/mushaf_color_scheme.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart';

void main() {
  test('each style maps to a CPAL palette and a page background', () {
    expect(MushafColorScheme.tajweed.palette, 0);
    expect(MushafColorScheme.tajweed.darkPage, isFalse);
    expect(MushafColorScheme.tajweedDark.palette, 1);
    expect(MushafColorScheme.tajweedDark.darkPage, isTrue);
    expect(MushafColorScheme.plain.palette, 3);
    expect(MushafColorScheme.plainDark.palette, 4);
    expect(MushafColorScheme.plainDark.darkPage, isTrue);
    // All six QPC V4 palettes are exposed as selectable styles.
    expect(MushafColorScheme.values, hasLength(6));
    expect(MushafColorScheme.values.map((s) => s.palette).toSet(), {
      0,
      1,
      2,
      3,
      4,
      5,
    });
  });

  test('fromStorage falls back to tajweed for unknown or missing values', () {
    expect(MushafColorScheme.fromStorage(null), MushafColorScheme.tajweed);
    expect(
      MushafColorScheme.fromStorage('nonsense'),
      MushafColorScheme.tajweed,
    );
    expect(MushafColorScheme.fromStorage('plain'), MushafColorScheme.plain);
    expect(
      MushafColorScheme.fromStorage('plain_dark'),
      MushafColorScheme.plainDark,
    );
  });

  test('defaults to tajweed and persists a selection', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(mushafColorSchemeProvider),
      MushafColorScheme.tajweed,
    );

    await container
        .read(mushafColorSchemeProvider.notifier)
        .select(MushafColorScheme.plainDark);

    expect(
      container.read(mushafColorSchemeProvider),
      MushafColorScheme.plainDark,
    );
    expect(prefs.getString('mushaf.color_scheme'), 'plain_dark');
  });

  test('reads a persisted selection on build', () async {
    SharedPreferences.setMockInitialValues({
      'mushaf.color_scheme': 'tajweed_warm',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(
      container.read(mushafColorSchemeProvider),
      MushafColorScheme.tajweedWarm,
    );
  });
}
