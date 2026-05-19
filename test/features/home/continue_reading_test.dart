import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/quran_repository.dart';
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/domain/quran/surah.dart';
import 'package:quran_player/features/home/home_page.dart';

import '../../_fakes/fake_quran_repository.dart';
import '../../_fakes/fake_tafsir_bootstrap.dart';
import '../../_fakes/fake_user_data_repositories.dart';

const _surahs = [
  Surah(
    number: 1,
    nameArabic: 'الفاتحة',
    nameLatin: 'Al-Fatihah',
    revelation: Revelation.meccan,
    ayahCount: 7,
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

Future<GoRouter> _pumpHome(
  WidgetTester tester, {
  AyahKey? recordedPosition,
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
        readingPositionRepositoryProvider.overrideWithValue(
          FakeReadingPositionRepository(recordedPosition),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();

  return GoRouter.of(tester.element(find.byKey(HomePageKeys.title)));
}

void main() {
  testWidgets('shows a "Continue reading" card when a position is recorded', (
    tester,
  ) async {
    await _pumpHome(tester, recordedPosition: AyahKey(18, 10));

    expect(find.byKey(HomePageKeys.continueReading), findsOneWidget);
    expect(find.text('Continue reading'), findsOneWidget);
    expect(find.textContaining('Al-Kahf'), findsWidgets);
    expect(find.textContaining('18:10'), findsOneWidget);
  });

  testWidgets('shows no card when no position has been recorded', (
    tester,
  ) async {
    await _pumpHome(tester);

    expect(find.byKey(HomePageKeys.continueReading), findsNothing);
    expect(find.byKey(HomePageKeys.list), findsOneWidget);
  });

  testWidgets('activating the card opens the ayah reader deep link', (
    tester,
  ) async {
    final router = await _pumpHome(tester, recordedPosition: AyahKey(18, 10));

    await tester.tap(find.byKey(HomePageKeys.continueReading));
    await tester.pumpAndSettle();

    final location = router.routeInformationProvider.value.uri.toString();
    expect(location, startsWith('/reader/surah/18'));
    expect(location, contains('anchor=18:10'));
  });
}
