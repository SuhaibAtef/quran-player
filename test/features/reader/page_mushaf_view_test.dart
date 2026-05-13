import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/app/theme/app_theme.dart';
import 'package:quran_player/features/reader/widgets/page_mushaf_view.dart';

void main() {
  testWidgets('font load failure reports render-unavailable callback', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    var unavailable = false;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
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
