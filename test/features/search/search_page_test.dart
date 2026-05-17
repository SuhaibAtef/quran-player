import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/app.dart';
import 'package:quran_player/app/router/route_names.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/quran/integrity_checker.dart';
import 'package:quran_player/data/quran/manifest.dart';
import 'package:quran_player/data/quran/mushaf_engine.dart';
import 'package:quran_player/data/quran/mushaf_locator_provider.dart';
import 'package:quran_player/data/quran/providers.dart';
import 'package:quran_player/data/tafsir/providers.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/quran_repository.dart';
import 'package:quran_player/domain/quran/quran_search_result.dart';
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/domain/quran/surah.dart';
import 'package:quran_player/features/home/home_page.dart';
import 'package:quran_player/features/reader/reader_screen.dart';
import 'package:quran_player/features/search/search_page.dart';

import '../../_fakes/fake_quran_repository.dart';
import '../../_fakes/fake_tafsir_bootstrap.dart';

final _source = QuranSource(
  name: 'TestSource',
  edition: 'test',
  version: '0',
  url: 'about:blank',
  license: 'test',
  retrievedAtUtc: DateTime.utc(2026, 1, 1),
);

const _surahs = [
  Surah(
    number: 1,
    nameArabic: 'الفاتحة',
    nameLatin: 'Al-Fatihah',
    revelation: Revelation.meccan,
    ayahCount: 7,
  ),
  Surah(
    number: 2,
    nameArabic: 'البقرة',
    nameLatin: 'Al-Baqarah',
    revelation: Revelation.medinan,
    ayahCount: 286,
  ),
];

final Map<AyahKey, Ayah> _ayahs = {
  AyahKey(2, 255): Ayah(
    key: AyahKey(2, 255),
    text: 'الله لا إله إلا هو الحي القيوم',
  ),
};

final _searchResult = QuranSearchResult(
  key: AyahKey(2, 255),
  text: 'الله لا إله إلا هو الحي القيوم',
  surahNameArabic: 'البقرة',
  surahNameLatin: 'Al-Baqarah',
);

QuranBootstrap _bootstrap(QuranRepository repo) {
  return QuranBootstrap(
    repository: repo,
    manifest: QuranManifest(
      schemaVersion: 1,
      source: _source,
      surahCount: 114,
      ayahCount: 6236,
      dbSha256: '0' * 64,
      textSha256: '0' * 64,
      fetchUrl: '',
    ),
    report: const IntegrityReport(dbSha256: 'fake', skippedHash: true),
  );
}

Future<GoRouter> _pumpSearch(
  WidgetTester tester,
  QuranRepository repo, {
  Map<String, Object> prefsSeed = const {},
}) async {
  SharedPreferences.setMockInitialValues(prefsSeed);
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

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
        // The reader's QUL engine is irrelevant to search-page navigation;
        // override it so the `/reader/ayah` redirect resolves synchronously
        // (text mode) instead of opening the real engine off-frame.
        mushafEngineProvider.overrideWith(
          (ref) => const MushafEngine.unavailable(),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();

  final router = GoRouter.of(tester.element(find.byKey(HomePageKeys.title)));
  router.go(RoutePaths.search);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('Search page starts idle without querying the repository', (
    tester,
  ) async {
    final repo = _CountingSearchRepository();
    await _pumpSearch(tester, repo);

    expect(find.byKey(SearchPageKeys.title), findsOneWidget);
    expect(find.byKey(SearchPageKeys.input), findsOneWidget);
    expect(find.byKey(SearchPageKeys.idle), findsOneWidget);
    expect(repo.searchCalls, 0);
  });

  testWidgets('Search page shows loading while search is pending', (
    tester,
  ) async {
    final repo = _PendingSearchRepository();
    await _pumpSearch(tester, repo);

    await tester.enterText(find.byKey(SearchPageKeys.input), 'الله');
    await tester.tap(find.byKey(SearchPageKeys.submit));
    await tester.pump();

    expect(find.byKey(SearchPageKeys.loading), findsOneWidget);
    expect(repo.searchCalls, 1);

    repo.completer.complete(const Result.ok([]));
    await tester.pumpAndSettle();
  });

  testWidgets('Search page ignores onSubmit while a search is pending', (
    tester,
  ) async {
    final repo = _PendingSearchRepository();
    await _pumpSearch(tester, repo);

    await tester.enterText(find.byKey(SearchPageKeys.input), 'الله');
    await tester.tap(find.byKey(SearchPageKeys.submit));
    await tester.pump();

    expect(find.byKey(SearchPageKeys.loading), findsOneWidget);
    expect(repo.searchCalls, 1);

    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pump();
    expect(repo.searchCalls, 1);

    repo.completer.complete(const Result.ok([]));
    await tester.pumpAndSettle();
  });

  testWidgets('Search page renders repository results', (tester) async {
    final repo = FakeQuranRepository(
      surahs: _surahs,
      ayahs: _ayahs,
      searchResult: Result.ok([_searchResult]),
    );
    await _pumpSearch(tester, repo);

    await tester.enterText(find.byKey(SearchPageKeys.input), 'الله');
    await tester.tap(find.byKey(SearchPageKeys.submit));
    await tester.pumpAndSettle();

    expect(find.byKey(SearchPageKeys.results), findsOneWidget);
    expect(find.byKey(SearchPageKeys.resultTile(2, 255)), findsOneWidget);
    expect(find.textContaining('2:255'), findsOneWidget);
    expect(find.textContaining('Al-Baqarah'), findsOneWidget);
    expect(find.textContaining('الله لا إله'), findsOneWidget);
  });

  testWidgets('Search page handles empty result sets without stale rows', (
    tester,
  ) async {
    final repo = FakeQuranRepository(
      surahs: _surahs,
      ayahs: _ayahs,
      searchResult: const Result.ok([]),
    );
    await _pumpSearch(tester, repo);

    await tester.enterText(find.byKey(SearchPageKeys.input), 'missing');
    await tester.tap(find.byKey(SearchPageKeys.submit));
    await tester.pumpAndSettle();

    expect(find.byKey(SearchPageKeys.empty), findsOneWidget);
    expect(find.byKey(SearchPageKeys.resultTile(2, 255)), findsNothing);
  });

  testWidgets('Search page validates empty submissions without repo calls', (
    tester,
  ) async {
    final repo = _CountingSearchRepository();
    await _pumpSearch(tester, repo);

    await tester.tap(find.byKey(SearchPageKeys.submit));
    await tester.pumpAndSettle();

    expect(find.byKey(SearchPageKeys.error), findsOneWidget);
    expect(repo.searchCalls, 0);
  });

  testWidgets('Search page renders repository failures as non-fatal errors', (
    tester,
  ) async {
    final repo = FakeQuranRepository(
      searchResult: const Result.err(DataAccessFailure('boom')),
    );
    await _pumpSearch(tester, repo);

    await tester.enterText(find.byKey(SearchPageKeys.input), 'الله');
    await tester.tap(find.byKey(SearchPageKeys.submit));
    await tester.pumpAndSettle();

    expect(find.byKey(SearchPageKeys.error), findsOneWidget);
    expect(find.textContaining('boom'), findsOneWidget);
    expect(find.byKey(SearchPageKeys.title), findsOneWidget);
  });

  testWidgets('activating a result navigates through the ayah reader route', (
    tester,
  ) async {
    final repo = FakeQuranRepository(
      surahs: _surahs,
      ayahs: _ayahs,
      searchResult: Result.ok([_searchResult]),
    );
    final router = await _pumpSearch(
      tester,
      repo,
      prefsSeed: const {'reader.mode': 'text'},
    );

    await tester.enterText(find.byKey(SearchPageKeys.input), 'الله');
    await tester.tap(find.byKey(SearchPageKeys.submit));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SearchPageKeys.resultTile(2, 255)));
    await tester.pumpAndSettle();

    final location = router.routeInformationProvider.value.uri.toString();
    expect(location, startsWith('/reader/surah/2'));
    expect(location, contains('anchor=2:255'));
    expect(find.byKey(ReaderScreenKeys.textMode), findsOneWidget);
  });
}

class _CountingSearchRepository extends FakeQuranRepository {
  int searchCalls = 0;

  @override
  Future<Result<List<QuranSearchResult>>> searchAyahs(
    String query, {
    int limit = 50,
  }) async {
    searchCalls++;
    return Result.ok([_searchResult]);
  }
}

class _PendingSearchRepository extends FakeQuranRepository {
  int searchCalls = 0;
  final Completer<Result<List<QuranSearchResult>>> completer = Completer();

  @override
  Future<Result<List<QuranSearchResult>>> searchAyahs(
    String query, {
    int limit = 50,
  }) {
    searchCalls++;
    return completer.future;
  }
}
