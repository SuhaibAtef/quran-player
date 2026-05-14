import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/app.dart';
import 'package:quran_player/app/router/route_names.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/quran/integrity_checker.dart';
import 'package:quran_player/data/quran/manifest.dart';
import 'package:quran_player/data/quran/providers.dart';
import 'package:quran_player/data/tafsir/providers.dart';
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/features/home/home_page.dart';
import 'package:quran_player/features/settings/settings_page.dart';

import '../../_fakes/fake_quran_repository.dart';
import '../../_fakes/fake_tafsir_bootstrap.dart';

final QuranSource _fixture = QuranSource(
  name: 'Tanzil',
  edition: 'Uthmani',
  version: '1.0.2',
  url: 'https://tanzil.net/download/',
  license: 'Tanzil Quran Text License (non-commercial, attribution)',
  retrievedAtUtc: DateTime.utc(2026, 5, 9),
);

QuranBootstrap _bootstrap() {
  final repo = FakeQuranRepository(source: _fixture);
  return QuranBootstrap(
    repository: repo,
    manifest: QuranManifest(
      schemaVersion: 1,
      source: _fixture,
      surahCount: 114,
      ayahCount: 6236,
      dbSha256: '0' * 64,
      textSha256: '0' * 64,
      fetchUrl: '',
    ),
    report: const IntegrityReport(dbSha256: 'fake', skippedHash: true),
  );
}

Future<void> _pump(WidgetTester tester) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = FakeQuranRepository(source: _fixture);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quranBootstrapProvider.overrideWith(
          (ref) async => Result.ok(_bootstrap()),
        ),
        tafsirBootstrapProvider.overrideWith(
          (ref) async => Result.ok(fakeTafsirBootstrap()),
        ),
        quranRepositoryProvider.overrideWithValue(repo),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();

  // Navigate to Settings.
  final ctx = tester.element(find.byKey(HomePageKeys.title));
  GoRouter.of(ctx).go(RoutePaths.settings);
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Settings renders Quran source attribution', (tester) async {
    await _pump(tester);

    expect(find.byKey(SettingsPageKeys.sourceSection), findsOneWidget);
    expect(find.byKey(SettingsPageKeys.sourceName), findsOneWidget);
    expect(find.text('Tanzil'), findsOneWidget);
    expect(find.text('Uthmani'), findsOneWidget);
    expect(find.text('Version 1.0.2'), findsOneWidget);
    expect(
      find.text('Tanzil Quran Text License (non-commercial, attribution)'),
      findsOneWidget,
    );
    expect(find.text('https://tanzil.net/download/'), findsOneWidget);
  });

  testWidgets('Settings renders tafsir source attribution', (tester) async {
    await _pump(tester);

    expect(find.byKey(SettingsPageKeys.tafsirSection), findsOneWidget);
    expect(find.byKey(SettingsPageKeys.tafsirName), findsOneWidget);
    // Fixture comes from fakeTafsirBootstrap()'s default TafsirSource:
    // name=TestTafsir, publisher=Test Publisher, version=test, url=about:blank.
    expect(find.text('TestTafsir'), findsOneWidget);
    expect(find.text('Test Publisher'), findsOneWidget);
    expect(find.text('Version test'), findsOneWidget);
    expect(find.byKey(SettingsPageKeys.tafsirUrl), findsOneWidget);
  });

  testWidgets('Settings renders the QCF mushaf attribution', (tester) async {
    await _pump(tester);

    // The QCF section lives at the bottom of the Settings ListView; scroll it
    // into the viewport before asserting on it (otherwise the lazy list has
    // not built it yet).
    final scrollable = find.descendant(
      of: find.byKey(SettingsPageKeys.list),
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.byKey(SettingsPageKeys.qcfSection),
      400,
      scrollable: scrollable,
    );

    expect(find.byKey(SettingsPageKeys.qcfSection), findsOneWidget);
    expect(find.text('qcf_quran_plus'), findsOneWidget);
    expect(find.textContaining('0.0.8'), findsOneWidget);
  });

  testWidgets('Reader section toggles the mode and persists to prefs', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(SettingsPageKeys.readerSection), findsOneWidget);
    expect(find.byKey(SettingsPageKeys.readerOptionPage), findsOneWidget);
    expect(find.byKey(SettingsPageKeys.readerOptionText), findsOneWidget);

    await tester.tap(find.byKey(SettingsPageKeys.readerOptionText));
    await tester.pumpAndSettle();

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('reader.mode'), 'text');

    await tester.tap(find.byKey(SettingsPageKeys.readerOptionPage));
    await tester.pumpAndSettle();
    expect(prefs.getString('reader.mode'), 'page');
  });

  testWidgets('Tajweed switch defaults off and persists when toggled', (
    tester,
  ) async {
    await _pump(tester);

    expect(find.byKey(SettingsPageKeys.readerTajweedSwitch), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool('reader.tajweed_enabled'), isNull);

    await tester.tap(find.byKey(SettingsPageKeys.readerTajweedSwitch));
    await tester.pumpAndSettle();
    expect(prefs.getBool('reader.tajweed_enabled'), isTrue);

    await tester.tap(find.byKey(SettingsPageKeys.readerTajweedSwitch));
    await tester.pumpAndSettle();
    expect(prefs.getBool('reader.tajweed_enabled'), isFalse);
  });
}
