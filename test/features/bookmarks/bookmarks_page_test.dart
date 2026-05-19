import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/router/route_names.dart';
import 'package:quran_player/app/app.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/app/state/user_db_provider.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/quran/integrity_checker.dart';
import 'package:quran_player/data/quran/manifest.dart';
import 'package:quran_player/data/quran/mushaf_engine.dart';
import 'package:quran_player/data/quran/mushaf_locator_provider.dart';
import 'package:quran_player/data/quran/providers.dart';
import 'package:quran_player/data/tafsir/providers.dart';
import 'package:quran_player/domain/bookmarks/bookmark_repository.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/quran_repository.dart';
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/domain/quran/surah.dart';
import 'package:quran_player/features/bookmarks/bookmarks_page.dart';
import 'package:quran_player/features/home/home_page.dart';
import 'package:quran_player/features/reader/reader_screen.dart';

import '../../_fakes/fake_quran_repository.dart';
import '../../_fakes/fake_tafsir_bootstrap.dart';
import '../../_fakes/fake_user_data_repositories.dart';

const _surahs = [
  Surah(
    number: 2,
    nameArabic: 'البقرة',
    nameLatin: 'Al-Baqarah',
    revelation: Revelation.medinan,
    ayahCount: 286,
  ),
  Surah(
    number: 18,
    nameArabic: 'الكهف',
    nameLatin: 'Al-Kahf',
    revelation: Revelation.meccan,
    ayahCount: 110,
  ),
];

final Map<AyahKey, Ayah> _ayahs = {
  AyahKey(2, 255): Ayah(key: AyahKey(2, 255), text: 'اللَّه لا إله إلا هو'),
  AyahKey(18, 10): Ayah(key: AyahKey(18, 10), text: 'إذ أوى الفتية إلى الكهف'),
};

QuranBootstrap _bootstrap(QuranRepository repo) {
  return QuranBootstrap(
    repository: repo,
    manifest: QuranManifest(
      schemaVersion: 1,
      source: QuranSource(
        name: 'TestSource',
        edition: 'test',
        version: '0',
        url: 'about:blank',
        license: 'test',
        retrievedAtUtc: DateTime.utc(2026, 1, 1),
      ),
      surahCount: 114,
      ayahCount: 6236,
      dbSha256: '0' * 64,
      textSha256: '0' * 64,
      fetchUrl: '',
    ),
    report: const IntegrityReport(dbSha256: 'fake', skippedHash: true),
  );
}

Future<GoRouter> _pumpBookmarks(
  WidgetTester tester, {
  required BookmarkRepository? bookmarkRepo,
  UserDbHealth health = UserDbHealth.ready,
}) async {
  SharedPreferences.setMockInitialValues(const {'reader.mode': 'text'});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  final repo = FakeQuranRepository(surahs: _surahs, ayahs: _ayahs);

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
        mushafEngineProvider.overrideWith(
          (ref) => const MushafEngine.unavailable(),
        ),
        userDbHealthProvider.overrideWithValue(AsyncData(health)),
        bookmarkRepositoryProvider.overrideWithValue(bookmarkRepo),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();

  final router = GoRouter.of(tester.element(find.byKey(HomePageKeys.title)));
  router.go(RoutePaths.bookmarks);
  await tester.pumpAndSettle();
  return router;
}

void main() {
  testWidgets('lists saved bookmarks newest-first', (tester) async {
    await _pumpBookmarks(
      tester,
      bookmarkRepo: FakeBookmarkRepository(
        initial: [AyahKey(2, 255), AyahKey(18, 10)],
      ),
    );

    expect(find.byKey(BookmarksPageKeys.list), findsOneWidget);
    expect(find.byKey(BookmarksPageKeys.tile(2, 255)), findsOneWidget);
    expect(find.byKey(BookmarksPageKeys.tile(18, 10)), findsOneWidget);
    expect(find.textContaining('Al-Kahf'), findsOneWidget);
  });

  testWidgets('shows the empty state when there are no bookmarks', (
    tester,
  ) async {
    await _pumpBookmarks(tester, bookmarkRepo: FakeBookmarkRepository());

    expect(find.byKey(BookmarksPageKeys.empty), findsOneWidget);
    expect(find.byKey(BookmarksPageKeys.list), findsNothing);
  });

  testWidgets('activating a row opens the ayah reader deep link', (
    tester,
  ) async {
    final router = await _pumpBookmarks(
      tester,
      bookmarkRepo: FakeBookmarkRepository(initial: [AyahKey(2, 255)]),
    );

    await tester.tap(find.byKey(BookmarksPageKeys.tile(2, 255)));
    await tester.pumpAndSettle();

    final location = router.routeInformationProvider.value.uri.toString();
    expect(location, startsWith('/reader/surah/2'));
    expect(location, contains('anchor=2:255'));
    expect(find.byKey(ReaderScreenKeys.root), findsOneWidget);
  });

  testWidgets('removing a bookmark drops its row', (tester) async {
    await _pumpBookmarks(
      tester,
      bookmarkRepo: FakeBookmarkRepository(initial: [AyahKey(2, 255)]),
    );

    expect(find.byKey(BookmarksPageKeys.tile(2, 255)), findsOneWidget);
    await tester.tap(find.byKey(BookmarksPageKeys.remove(2, 255)));
    await tester.pumpAndSettle();

    expect(find.byKey(BookmarksPageKeys.tile(2, 255)), findsNothing);
    expect(find.byKey(BookmarksPageKeys.empty), findsOneWidget);
  });

  testWidgets('shows a non-fatal notice when user.db is unavailable', (
    tester,
  ) async {
    await _pumpBookmarks(
      tester,
      bookmarkRepo: null,
      health: UserDbHealth.failed,
    );

    expect(find.byKey(BookmarksPageKeys.unavailable), findsOneWidget);
    expect(find.byKey(BookmarksPageKeys.list), findsNothing);
  });
}
