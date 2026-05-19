import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/app.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/core/error/failure.dart';
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/quran/integrity_checker.dart';
import 'package:quran_player/data/quran/manifest.dart';
import 'package:quran_player/data/quran/providers.dart';
import 'package:quran_player/data/tafsir/providers.dart';
import 'package:quran_player/domain/quran/quran_repository.dart';
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/domain/quran/surah.dart';
import 'package:quran_player/features/home/home_page.dart';
import 'package:quran_player/features/surahs/state/surahs_provider.dart';

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
    ayahCount: 1,
  ),
);

Future<void> _pump(WidgetTester tester, List<Override> overrides) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        ...overrides,
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Surahs list renders 114 entries on a healthy DB', (
    tester,
  ) async {
    final repo = FakeQuranRepository(surahs: _full114());
    await _pump(tester, [
      quranBootstrapProvider.overrideWith(
        (ref) async => Result.ok(_bootstrap(repo)),
      ),
      tafsirBootstrapProvider.overrideWith(
        (ref) async => Result.ok(fakeTafsirBootstrap()),
      ),
      // Override the repository provider directly so the surahs provider sees
      // the fake without going through the real bootstrap.
      quranRepositoryProvider.overrideWithValue(repo),
    ]);

    expect(find.byKey(HomePageKeys.list), findsOneWidget);
    // First-screen items are mounted by the lazy ListView; verify a few.
    expect(find.textContaining('Surah 1 ·'), findsOneWidget);
    expect(find.textContaining('Surah 2 ·'), findsOneWidget);

    // Scroll to the bottom of the lazy list and verify the last entry.
    final listFinder = find.byKey(HomePageKeys.list);
    final scrollable = find.descendant(
      of: listFinder,
      matching: find.byType(Scrollable),
    );
    await tester.scrollUntilVisible(
      find.textContaining('Surah 114 ·'),
      600,
      scrollable: scrollable,
    );
    expect(find.textContaining('Surah 114 ·'), findsOneWidget);
  });

  testWidgets('Surahs list shows error state when the repo fails', (
    tester,
  ) async {
    final repo = _FailingRepo();
    await _pump(tester, [
      quranBootstrapProvider.overrideWith(
        (ref) async => Result.ok(_bootstrap(repo)),
      ),
      tafsirBootstrapProvider.overrideWith(
        (ref) async => Result.ok(fakeTafsirBootstrap()),
      ),
      quranRepositoryProvider.overrideWithValue(repo),
      surahsProvider.overrideWith(
        (ref) async => Result.err(const DataAccessFailure('boom')),
      ),
    ]);

    expect(find.byKey(HomePageKeys.error), findsOneWidget);
    expect(find.byKey(HomePageKeys.list), findsNothing);
  });
}

class _FailingRepo extends FakeQuranRepository {
  _FailingRepo();

  @override
  Future<Result<List<Surah>>> listSurahs() async =>
      Result.err(const DataAccessFailure('boom'));
}
