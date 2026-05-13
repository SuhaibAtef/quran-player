import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/state/tajweed_provider.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart'
    show sharedPreferencesProvider;

ProviderContainer _container(SharedPreferences prefs) {
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
  addTearDown(container.dispose);
  return container;
}

Future<SharedPreferences> _prefs(Map<String, Object> seed) async {
  SharedPreferences.setMockInitialValues(seed);
  return SharedPreferences.getInstance();
}

void main() {
  group('tajweedEnabledProvider', () {
    test('default is false when prefs are empty', () async {
      final prefs = await _prefs(<String, Object>{});
      final c = _container(prefs);
      expect(c.read(tajweedEnabledProvider), isFalse);
    });

    test('reads previously persisted value', () async {
      final prefs = await _prefs(<String, Object>{
        'reader.tajweed_enabled': true,
      });
      final c = _container(prefs);
      expect(c.read(tajweedEnabledProvider), isTrue);
    });

    test('setEnabled round-trips and persists to prefs', () async {
      final prefs = await _prefs(<String, Object>{});
      final c = _container(prefs);

      expect(c.read(tajweedEnabledProvider), isFalse);

      await c.read(tajweedEnabledProvider.notifier).setEnabled(true);
      expect(c.read(tajweedEnabledProvider), isTrue);
      expect(prefs.getBool('reader.tajweed_enabled'), isTrue);

      await c.read(tajweedEnabledProvider.notifier).setEnabled(false);
      expect(c.read(tajweedEnabledProvider), isFalse);
      expect(prefs.getBool('reader.tajweed_enabled'), isFalse);
    });

    test('setEnabled is a no-op when the value matches', () async {
      final prefs = await _prefs(<String, Object>{
        'reader.tajweed_enabled': true,
      });
      final c = _container(prefs);
      expect(c.read(tajweedEnabledProvider), isTrue);

      await prefs.setBool('reader.tajweed_enabled', true);
      await c.read(tajweedEnabledProvider.notifier).setEnabled(true);
      expect(prefs.getBool('reader.tajweed_enabled'), isTrue);
    });
  });
}
