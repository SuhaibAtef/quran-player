import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/app/theme/app_theme.dart';
import 'package:quran_player/data/quran/mushaf_engine.dart';
import 'package:quran_player/data/quran/mushaf_fonts.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/features/player/state/audio_player_controller.dart';
import 'package:quran_player/features/reader/widgets/page_mushaf_view.dart';
import 'package:tarteel_qul/fixtures.dart';
import 'package:tarteel_qul/tarteel_qul.dart' as qul;

import '../../_support/localized.dart';

void main() {
  // `tarteel_qul`'s deterministic demo layout — opened in setUpAll, outside the
  // testWidgets zone, because sqflite's isolate-backed open deadlocks inside
  // it. The test then never touches the gitignored QUL download.
  late MushafEngine demoEngine;

  setUpAll(() async {
    final source = DemoMushafAssetSource();
    final opened = await qul.MushafLayoutRepository.open(source);
    demoEngine = MushafEngine.forTest(
      repository: (opened as qul.MushafOk<qul.MushafLayoutRepository>).value,
      assetSource: source,
    );
  });

  Future<void> pumpReader(WidgetTester tester, {AyahKey? activeAyah}) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activePlaybackAyahProvider.overrideWithValue(activeAyah),
          // Degrade the QUL header fonts so the test exercises the plain
          // header fallback without loading real font assets.
          mushafHeaderFontsProvider.overrideWith((ref) => false),
        ],
        child: localized(
          FTheme(
            data: AppTheme.light,
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: SizedBox(
                width: 600,
                height: 800,
                child: PageMushafView(engine: demoEngine, initialPage: 1),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('renders the engine MushafView with desktop nav buttons', (
    tester,
  ) async {
    await pumpReader(tester);

    expect(find.byKey(PageMushafViewKeys.root), findsOneWidget);
    expect(find.byType(qul.MushafView), findsOneWidget);
    expect(find.byKey(PageMushafViewKeys.nextButton), findsOneWidget);
    expect(find.byKey(PageMushafViewKeys.prevButton), findsOneWidget);
  });

  testWidgets('renders MushafView in the colour scheme\'s palette', (
    tester,
  ) async {
    await pumpReader(tester);

    final view = tester.widget<qul.MushafView>(find.byType(qul.MushafView));
    // The default colour style (tajweed) renders CPAL palette 0.
    expect(view.palette, 0);
  });

  testWidgets('passes the active playback ayah as a MushafView decoration', (
    tester,
  ) async {
    await pumpReader(tester, activeAyah: AyahKey(1, 1));

    final view = tester.widget<qul.MushafView>(find.byType(qul.MushafView));
    expect(view.decorations, hasLength(1));
    expect(view.decorations.single.ayah, const qul.AyahKey(1, 1));
  });

  testWidgets('passes no decoration when nothing is playing', (tester) async {
    await pumpReader(tester);

    final view = tester.widget<qul.MushafView>(find.byType(qul.MushafView));
    expect(view.decorations, isEmpty);
  });
}
