import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/app.dart';
import 'package:quran_player/app/state/reader_mode.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/quran/integrity_checker.dart';
import 'package:quran_player/data/quran/manifest.dart';
import 'package:quran_player/data/quran/mushaf_engine.dart';
import 'package:quran_player/data/quran/mushaf_fonts.dart';
import 'package:quran_player/data/quran/mushaf_locator_provider.dart';
import 'package:quran_player/data/quran/providers.dart';
import 'package:quran_player/data/tafsir/providers.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/quran_repository.dart';
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/domain/quran/surah.dart';
import 'package:quran_player/features/_errors/bootstrapping_screen.dart';
import 'package:quran_player/features/_errors/data_integrity_screen.dart';
import 'package:quran_player/features/home/home_page.dart';
import 'package:quran_player/features/reader/reader_screen.dart';
import 'package:tarteel_qul/fixtures.dart';
import 'package:tarteel_qul/tarteel_qul.dart' as qul;

import '../../_fakes/fake_quran_repository.dart';
import '../../_fakes/fake_tafsir_bootstrap.dart';

QuranBootstrap _bootstrap(QuranRepository repo) {
  final source = QuranSource(
    name: 'TestSource',
    edition: 'test',
    version: '0',
    url: '',
    license: '',
    retrievedAtUtc: DateTime.utc(2026, 1, 1),
  );
  return QuranBootstrap(
    repository: repo,
    manifest: QuranManifest(
      schemaVersion: 1,
      source: source,
      surahCount: 114,
      ayahCount: 6236,
      dbSha256: '0' * 64,
      textSha256: '0' * 64,
      fetchUrl: '',
    ),
    report: const IntegrityReport(dbSha256: 'fake', skippedHash: true),
  );
}

List<Surah> _full114() => List<Surah>.generate(
  114,
  (i) => Surah(
    number: i + 1,
    nameArabic: 'سورة ${i + 1}',
    nameLatin: 'Surah ${i + 1}',
    revelation: Revelation.meccan,
    ayahCount: i == 0 ? 7 : 286,
  ),
);

Map<AyahKey, Ayah> _seedAyahs() {
  final out = <AyahKey, Ayah>{};
  for (var ayah = 1; ayah <= 7; ayah++) {
    final key = AyahKey(1, ayah);
    out[key] = Ayah(key: key, text: 'الفاتحة آية $ayah');
  }
  for (var ayah = 1; ayah <= 286; ayah++) {
    final key = AyahKey(2, ayah);
    out[key] = Ayah(key: key, text: 'البقرة آية $ayah');
  }
  return out;
}

/// A non-fallback [MushafEngine] over `tarteel_qul`'s deterministic demo
/// layout — so the route tests do not depend on the gitignored QUL download.
/// The demo covers surah 1 (page 1) and surah 2 (pages 2–3).
///
/// Opened once in `setUpAll`, outside the `testWidgets` zone — sqflite's
/// isolate-backed open deadlocks if called inside it.
late MushafEngine _demoEngine;

Future<MushafEngine> _openDemoEngine() async {
  final source = DemoMushafAssetSource();
  final opened = await qul.MushafLayoutRepository.open(source);
  return MushafEngine.forTest(
    repository: (opened as qul.MushafOk<qul.MushafLayoutRepository>).value,
    assetSource: source,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  ReaderMode? readerMode,
  bool forceLocatorFallback = false,
  Map<String, Object>? prefsSeed,
}) async {
  SharedPreferences.setMockInitialValues(<String, Object>{
    if (readerMode != null) 'reader.mode': readerMode.storageKey,
    ...?prefsSeed,
  });
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final engine = forceLocatorFallback
      ? const MushafEngine.unavailable()
      : _demoEngine;

  final repo = FakeQuranRepository(surahs: _full114(), ayahs: _seedAyahs());
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        quranBootstrapProvider.overrideWith(
          (ref) async => Result.ok(_bootstrap(repo)),
        ),
        tafsirBootstrapProvider.overrideWith(
          (ref) async => Result.ok(fakeTafsirBootstrap()),
        ),
        quranRepositoryProvider.overrideWithValue(repo),
        mushafEngineProvider.overrideWith((ref) => engine),
        mushafHeaderFontsProvider.overrideWith((ref) => false),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

GoRouter _router(WidgetTester tester) {
  final candidates = <Finder>[
    find.byKey(HomePageKeys.title),
    find.byKey(ReaderScreenKeys.root),
  ];
  for (final f in candidates) {
    if (f.evaluate().isNotEmpty) return GoRouter.of(tester.element(f));
  }
  throw StateError('no router-bearing element on screen');
}

String _currentLocation(GoRouter router) {
  return router.routeInformationProvider.value.uri.toString();
}

void main() {
  setUpAll(() async {
    _demoEngine = await _openDemoEngine();
  });

  testWidgets('/reader/page/1 opens ReaderScreen in page mode', (tester) async {
    await _pump(tester);
    _router(tester).go('/reader/page/1');
    await tester.pumpAndSettle();
    expect(find.byKey(ReaderScreenKeys.root), findsOneWidget);
    expect(find.byKey(ReaderScreenKeys.pageMode), findsOneWidget);
    expect(find.byKey(ReaderScreenKeys.textMode), findsNothing);
  });

  testWidgets('/reader/surah/2 opens ReaderScreen in text mode', (
    tester,
  ) async {
    await _pump(tester);
    _router(tester).go('/reader/surah/2');
    await tester.pumpAndSettle();
    expect(find.byKey(ReaderScreenKeys.root), findsOneWidget);
    expect(find.byKey(ReaderScreenKeys.textMode), findsOneWidget);
    expect(find.byKey(ReaderScreenKeys.pageMode), findsNothing);
  });

  testWidgets(
    '/reader/ayah/2/3 in page mode redirects to /reader/page/2 with anchor',
    (tester) async {
      await _pump(tester, readerMode: ReaderMode.page);
      final router = _router(tester);
      router.go('/reader/ayah/2/3');
      await tester.pumpAndSettle();
      final loc = _currentLocation(router);
      expect(loc, startsWith('/reader/page/2'));
      expect(loc, contains('anchor=2:3'));
      expect(find.byKey(ReaderScreenKeys.pageMode), findsOneWidget);
    },
  );

  testWidgets(
    '/reader/ayah/2/3 in text mode redirects to /reader/surah/2 with anchor',
    (tester) async {
      await _pump(tester, readerMode: ReaderMode.text);
      final router = _router(tester);
      router.go('/reader/ayah/2/3');
      await tester.pumpAndSettle();
      final loc = _currentLocation(router);
      expect(loc, startsWith('/reader/surah/2'));
      expect(loc, contains('anchor=2:3'));
      expect(find.byKey(ReaderScreenKeys.textMode), findsOneWidget);
    },
  );

  testWidgets('/reader/page/700 (out of range) redirects to /', (tester) async {
    await _pump(tester);
    final router = _router(tester);
    router.go('/reader/page/700');
    await tester.pumpAndSettle();
    expect(_currentLocation(router), '/');
    expect(find.byKey(HomePageKeys.title), findsOneWidget);
    expect(find.byKey(ReaderScreenKeys.root), findsNothing);
  });

  testWidgets('/reader/surah/115 (out of range) redirects to /', (
    tester,
  ) async {
    await _pump(tester);
    final router = _router(tester);
    router.go('/reader/surah/115');
    await tester.pumpAndSettle();
    expect(_currentLocation(router), '/');
    expect(find.byKey(ReaderScreenKeys.root), findsNothing);
  });

  testWidgets('/reader/ayah/1/8 (ayah not in surah) redirects to /', (
    tester,
  ) async {
    await _pump(tester);
    final router = _router(tester);
    router.go('/reader/ayah/1/8');
    await tester.pumpAndSettle();
    expect(_currentLocation(router), '/');
    expect(find.byKey(ReaderScreenKeys.root), findsNothing);
  });

  testWidgets(
    '/reader/ayah/1/8 still redirects to / when page renderer is unavailable',
    (tester) async {
      await _pump(
        tester,
        readerMode: ReaderMode.page,
        forceLocatorFallback: true,
      );
      final router = _router(tester);
      router.go('/reader/ayah/1/8');
      await tester.pumpAndSettle();
      expect(_currentLocation(router), '/');
      expect(find.byKey(ReaderScreenKeys.root), findsNothing);
    },
  );

  testWidgets('/reader/ayah/0/1 (invalid surah) redirects to /', (
    tester,
  ) async {
    await _pump(tester);
    final router = _router(tester);
    router.go('/reader/ayah/0/1');
    await tester.pumpAndSettle();
    expect(_currentLocation(router), '/');
  });

  testWidgets('/this-does-not-exist still redirects to / (regression)', (
    tester,
  ) async {
    await _pump(tester);
    final router = _router(tester);
    router.go('/this-route-does-not-exist');
    await tester.pumpAndSettle();
    expect(_currentLocation(router), '/');
  });

  testWidgets(
    'page-mode route auto-switches to text-mode + banner when the engine is '
    'in fallback (graceful degrade)',
    (tester) async {
      await _pump(
        tester,
        readerMode: ReaderMode.page,
        forceLocatorFallback: true,
      );
      _router(tester).go('/reader/page/42');
      await tester.pumpAndSettle();
      expect(find.byKey(ReaderScreenKeys.root), findsOneWidget);
      expect(find.byKey(ReaderScreenKeys.fallbackBanner), findsOneWidget);
      expect(find.byKey(ReaderScreenKeys.textMode), findsOneWidget);
      expect(find.byKey(ReaderScreenKeys.pageMode), findsNothing);
      // The fallback must NOT trigger the data-integrity error screen.
      expect(find.byType(DataIntegrityScreen), findsNothing);
      expect(find.byType(BootstrappingScreen), findsNothing);
    },
  );

  testWidgets(
    'fallback engine + ayah deep link routes to text mode rather than /',
    (tester) async {
      await _pump(
        tester,
        readerMode: ReaderMode.page,
        forceLocatorFallback: true,
      );
      final router = _router(tester);
      router.go('/reader/ayah/2/255');
      await tester.pumpAndSettle();
      // Without QUL coordinates we cannot verify the ayah's page; trust the
      // repository-validated input and route to the surah (text-mode) view.
      expect(_currentLocation(router), startsWith('/reader/surah/2'));
      expect(find.byKey(ReaderScreenKeys.textMode), findsOneWidget);
    },
  );

  testWidgets('tapping a Surahs list tile opens the reader at ayah 1', (
    tester,
  ) async {
    await _pump(tester, readerMode: ReaderMode.text);
    expect(find.byKey(HomePageKeys.list), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home.surah_tile.1')));
    await tester.pumpAndSettle();

    expect(find.byKey(ReaderScreenKeys.root), findsOneWidget);
    final loc = _currentLocation(_router(tester));
    expect(loc, startsWith('/reader/surah/1'));
  });
}
