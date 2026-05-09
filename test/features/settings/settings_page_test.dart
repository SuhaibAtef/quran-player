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
import 'package:quran_player/domain/quran/quran_source.dart';
import 'package:quran_player/features/home/home_page.dart';
import 'package:quran_player/features/settings/settings_page.dart';

import '../../_fakes/fake_quran_repository.dart';

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
}
