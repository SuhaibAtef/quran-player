import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/app.dart';
import 'package:quran_player/app/router/route_names.dart';
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
import 'package:quran_player/features/home/home_page.dart';
import 'package:quran_player/features/reader/widgets/text_reader_view.dart';
import 'package:quran_player/features/reader/widgets/verse_action_menu.dart';

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
];

final Map<AyahKey, Ayah> _ayahs = {
  AyahKey(2, 1): Ayah(key: AyahKey(2, 1), text: 'الم'),
  AyahKey(2, 2): Ayah(key: AyahKey(2, 2), text: 'ذلك الكتاب لا ريب فيه'),
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

Future<void> _pumpReaderAtSurah2(
  WidgetTester tester, {
  required BookmarkRepository? bookmarkRepo,
}) async {
  SharedPreferences.setMockInitialValues(const {});
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
        bookmarkRepositoryProvider.overrideWithValue(bookmarkRepo),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();

  final router = GoRouter.of(tester.element(find.byKey(HomePageKeys.title)));
  router.go(RoutePaths.readerSurahFor(2));
  await tester.pumpAndSettle();
}

Future<void> _openMenuForAyah1(WidgetTester tester) async {
  await tester.tap(find.byKey(TextReaderViewKeys.tile(2, 1)));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('tapping a verse opens the verse action menu', (tester) async {
    await _pumpReaderAtSurah2(tester, bookmarkRepo: FakeBookmarkRepository());

    await _openMenuForAyah1(tester);

    expect(find.byKey(VerseActionMenuKeys.sheet), findsOneWidget);
    expect(find.byKey(VerseActionMenuKeys.play), findsOneWidget);
    expect(find.byKey(VerseActionMenuKeys.bookmark), findsOneWidget);
    expect(find.byKey(VerseActionMenuKeys.highlight), findsOneWidget);
  });

  testWidgets('the bookmark action bookmarks an unsaved verse', (tester) async {
    final bookmarks = FakeBookmarkRepository();
    await _pumpReaderAtSurah2(tester, bookmarkRepo: bookmarks);

    await _openMenuForAyah1(tester);
    await tester.tap(find.byKey(VerseActionMenuKeys.bookmark));
    await tester.pumpAndSettle();

    expect((await bookmarks.isBookmarked(AyahKey(2, 1))).valueOrNull, isTrue);
  });

  testWidgets('the bookmark action reflects an already-bookmarked verse', (
    tester,
  ) async {
    await _pumpReaderAtSurah2(
      tester,
      bookmarkRepo: FakeBookmarkRepository(initial: [AyahKey(2, 1)]),
    );

    await _openMenuForAyah1(tester);

    expect(find.text('Remove bookmark'), findsOneWidget);
    expect(find.text('Bookmark'), findsNothing);
  });

  testWidgets(
    'the menu omits the bookmark action when user.db is unavailable',
    (tester) async {
      await _pumpReaderAtSurah2(tester, bookmarkRepo: null);

      await _openMenuForAyah1(tester);

      expect(find.byKey(VerseActionMenuKeys.sheet), findsOneWidget);
      expect(find.byKey(VerseActionMenuKeys.play), findsOneWidget);
      expect(find.byKey(VerseActionMenuKeys.bookmark), findsNothing);
    },
  );
}
