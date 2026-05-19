import 'package:flutter/widgets.dart' show Locale;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/state/locale_provider.dart';
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
  group('AppLocaleOption.locale', () {
    test('system follows the platform (null locale)', () {
      expect(AppLocaleOption.system.locale, isNull);
    });

    test('english and arabic pin their locales', () {
      expect(AppLocaleOption.english.locale, const Locale('en'));
      expect(AppLocaleOption.arabic.locale, const Locale('ar'));
    });
  });

  group('localeProvider', () {
    test('defaults to system when prefs are empty', () async {
      final prefs = await _prefs(<String, Object>{});
      final c = _container(prefs);
      expect(c.read(localeProvider), AppLocaleOption.system);
    });

    test('reads a previously persisted value', () async {
      final prefs = await _prefs(<String, Object>{'app.locale': 'arabic'});
      final c = _container(prefs);
      expect(c.read(localeProvider), AppLocaleOption.arabic);
    });

    test('unknown stored value falls back to system', () async {
      final prefs = await _prefs(<String, Object>{'app.locale': 'klingon'});
      final c = _container(prefs);
      expect(c.read(localeProvider), AppLocaleOption.system);
    });

    test(
      'setOption round-trips and persists across a fresh container',
      () async {
        final prefs = await _prefs(<String, Object>{});
        final c = _container(prefs);
        expect(c.read(localeProvider), AppLocaleOption.system);

        await c.read(localeProvider.notifier).setOption(AppLocaleOption.arabic);
        expect(c.read(localeProvider), AppLocaleOption.arabic);
        expect(prefs.getString('app.locale'), 'arabic');

        // A fresh container reading the same prefs restores the choice.
        final c2 = _container(prefs);
        expect(c2.read(localeProvider), AppLocaleOption.arabic);
      },
    );
  });
}
