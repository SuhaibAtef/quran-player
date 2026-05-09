import 'dart:ui' show Size;

import 'package:flutter/material.dart' show ThemeMode;
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

import '_fakes/fake_quran_repository.dart';

QuranBootstrap _fakeBootstrap() {
  final repo = FakeQuranRepository();
  final source = QuranSource(
    name: 'TestSource',
    edition: 'test',
    version: '0',
    url: 'about:blank',
    license: 'test',
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

Future<void> _pumpApp(WidgetTester tester) async {
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
        quranBootstrapProvider.overrideWith(
          (ref) async => Result.ok(_fakeBootstrap()),
        ),
      ],
      child: const App(),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('home placeholder renders on launch', (tester) async {
    await _pumpApp(tester);
    expect(find.byKey(HomePageKeys.title), findsOneWidget);
    expect(find.byKey(HomePageKeys.body), findsOneWidget);
  });

  testWidgets('navigates to Settings via go_router', (tester) async {
    await _pumpApp(tester);

    final context = tester.element(find.byKey(HomePageKeys.title));
    GoRouter.of(context).go(RoutePaths.settings);
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsPageKeys.title), findsOneWidget);
    expect(find.byKey(SettingsPageKeys.themeSection), findsOneWidget);
  });

  testWidgets('switching to dark mode surfaces dark-only marker', (
    tester,
  ) async {
    await _pumpApp(tester);

    final context = tester.element(find.byKey(HomePageKeys.title));
    GoRouter.of(context).go(RoutePaths.settings);
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsPageKeys.darkOnlyMarker), findsNothing);

    final container = ProviderScope.containerOf(
      tester.element(find.byKey(SettingsPageKeys.title)),
    );
    await container.read(themeModeProvider.notifier).setMode(ThemeMode.dark);
    await tester.pumpAndSettle();

    expect(find.byKey(SettingsPageKeys.darkOnlyMarker), findsOneWidget);
  });

  testWidgets('unknown route redirects to home', (tester) async {
    await _pumpApp(tester);

    final context = tester.element(find.byKey(HomePageKeys.title));
    GoRouter.of(context).go('/this-route-does-not-exist');
    await tester.pumpAndSettle();

    expect(find.byKey(HomePageKeys.title), findsOneWidget);
  });
}
