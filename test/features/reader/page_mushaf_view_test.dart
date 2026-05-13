import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/app/theme/app_theme.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/features/player/state/audio_player_controller.dart';
import 'package:quran_player/features/reader/widgets/page_mushaf_view.dart';

void main() {
  testWidgets('passes active playback ayah as a QCF page highlight', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activePlaybackAyahProvider.overrideWithValue(AyahKey(1, 1)),
        ],
        child: FTheme(
          data: AppTheme.light,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: PageMushafView(
              initialPage: 1,
              loadInitialFont: (_) async {},
              preloadPages: (_, {int radius = 0}) async {},
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final pageView = tester.widget<qcf.QuranPageView>(
      find.byKey(PageMushafViewKeys.pageView),
    );
    expect(pageView.highlights, hasLength(1));
    expect(pageView.highlights.single.surah, 1);
    expect(pageView.highlights.single.verseNumber, 1);
    expect(pageView.highlights.single.page, 1);
  });

  testWidgets('font load failure reports render-unavailable callback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var unavailable = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          activePlaybackAyahProvider.overrideWithValue(null),
        ],
        child: FTheme(
          data: AppTheme.light,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: PageMushafView(
              initialPage: 1,
              loadInitialFont: (_) async => throw StateError('font missing'),
              preloadPages: (_, {int radius = 0}) async {},
              onRenderUnavailable: () => unavailable = true,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(unavailable, isTrue);
    expect(find.byKey(PageMushafViewKeys.pageView), findsNothing);
  });
}
