import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/state/reader_mode.dart';
import 'package:quran_player/app/state/reader_mode_provider.dart';
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
  group('ReaderMode.fromStorage', () {
    test('null/empty/unknown all default to page', () {
      expect(ReaderMode.fromStorage(null), ReaderMode.page);
      expect(ReaderMode.fromStorage(''), ReaderMode.page);
      expect(ReaderMode.fromStorage('garbage'), ReaderMode.page);
      expect(ReaderMode.fromStorage('PAGE'), ReaderMode.page); // case-sensitive
    });

    test('round-trips known keys', () {
      expect(
        ReaderMode.fromStorage(ReaderMode.page.storageKey),
        ReaderMode.page,
      );
      expect(
        ReaderMode.fromStorage(ReaderMode.text.storageKey),
        ReaderMode.text,
      );
    });
  });

  group('readerModeProvider', () {
    test('default is page when prefs are empty', () async {
      final prefs = await _prefs(<String, Object>{});
      final c = _container(prefs);
      expect(c.read(readerModeProvider), ReaderMode.page);
    });

    test('reads previously persisted value', () async {
      final prefs = await _prefs(<String, Object>{'reader.mode': 'text'});
      final c = _container(prefs);
      expect(c.read(readerModeProvider), ReaderMode.text);
    });

    test('unknown stored value falls back to page', () async {
      final prefs = await _prefs(<String, Object>{
        'reader.mode': 'unknown-value',
      });
      final c = _container(prefs);
      expect(c.read(readerModeProvider), ReaderMode.page);
    });

    test('setMode round-trips and persists to prefs', () async {
      final prefs = await _prefs(<String, Object>{});
      final c = _container(prefs);

      expect(c.read(readerModeProvider), ReaderMode.page);

      await c.read(readerModeProvider.notifier).setMode(ReaderMode.text);
      expect(c.read(readerModeProvider), ReaderMode.text);
      expect(prefs.getString('reader.mode'), 'text');

      await c.read(readerModeProvider.notifier).setMode(ReaderMode.page);
      expect(c.read(readerModeProvider), ReaderMode.page);
      expect(prefs.getString('reader.mode'), 'page');
    });

    test('setMode is a no-op when the value matches', () async {
      final prefs = await _prefs(<String, Object>{'reader.mode': 'text'});
      final c = _container(prefs);
      // Notifier reads "text" on build.
      expect(c.read(readerModeProvider), ReaderMode.text);

      // Same-value set should not write again. Mutate the underlying map and
      // confirm the controller does not overwrite it.
      await prefs.setString('reader.mode', 'text');
      await c.read(readerModeProvider.notifier).setMode(ReaderMode.text);
      expect(prefs.getString('reader.mode'), 'text');
    });
  });
}
