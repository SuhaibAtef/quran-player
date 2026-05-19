import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/app.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart'
    show sharedPreferencesProvider;
import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/data/quran/integrity_checker.dart';
import 'package:quran_player/data/quran/manifest.dart';
import 'package:quran_player/data/quran/providers.dart';
import 'package:quran_player/data/tafsir/providers.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/features/home/home_page.dart';
import 'package:quran_player/features/reader/widgets/text_reader_view.dart';

import '../_fakes/fake_quran_repository.dart';
import '../_fakes/fake_tafsir_bootstrap.dart';

QuranBootstrap _fakeBootstrap() {
  final source = QuranSource(
    name: 'TestSource',
    edition: 'test',
    version: '0',
    url: 'about:blank',
    license: 'test',
    retrievedAtUtc: DateTime.utc(2026, 1, 1),
  );
  return QuranBootstrap(
    repository: FakeQuranRepository(),
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

Future<void> _pumpApp(
  WidgetTester tester, {
  String? localePref,
  List<Override> extraOverrides = const [],
}) async {
  SharedPreferences.setMockInitialValues(
    localePref == null ? {} : {'app.locale': localePref},
  );
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
          (ref) async => Result.ok(_fakeBootstrap()),
        ),
        tafsirBootstrapProvider.overrideWith(
          (ref) async => Result.ok(fakeTafsirBootstrap()),
        ),
        ...extraOverrides,
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('Arabic locale renders RTL chrome with Arabic strings', (
    tester,
  ) async {
    await _pumpApp(tester, localePref: 'arabic');

    final ctx = tester.element(find.byKey(HomePageKeys.title));
    expect(Directionality.of(ctx), TextDirection.rtl);
    // navSurahs / surahsTitle — "السور" in app_ar.arb.
    expect(find.text('السور'), findsWidgets);
  });

  testWidgets('English locale renders LTR chrome with English strings', (
    tester,
  ) async {
    await _pumpApp(tester, localePref: 'english');

    final ctx = tester.element(find.byKey(HomePageKeys.title));
    expect(Directionality.of(ctx), TextDirection.ltr);
    expect(find.text('Surahs'), findsWidgets);
  });

  testWidgets('Quran content stays RTL even under an English UI', (
    tester,
  ) async {
    final ayahs = {
      for (var i = 1; i <= 3; i++)
        AyahKey(1, i): Ayah(key: AyahKey(1, i), text: 'آية $i'),
    };
    await _pumpApp(
      tester,
      localePref: 'english',
      extraOverrides: [
        quranRepositoryProvider.overrideWithValue(
          FakeQuranRepository(ayahs: ayahs),
        ),
      ],
    );

    final ctx = tester.element(find.byKey(HomePageKeys.title));
    expect(Directionality.of(ctx), TextDirection.ltr);

    GoRouter.of(ctx).go('/reader/surah/1');
    await tester.pumpAndSettle();

    final list = find.byKey(TextReaderViewKeys.list);
    expect(list, findsOneWidget);
    // The ayah list is wrapped in an RTL Directionality regardless of the
    // English UI chrome around it.
    final directionalities = tester.widgetList<Directionality>(
      find.ancestor(of: list, matching: find.byType(Directionality)),
    );
    expect(
      directionalities.any((d) => d.textDirection == TextDirection.rtl),
      isTrue,
    );
  });
}
