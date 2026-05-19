import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:quran_player/app/state/theme_mode_provider.dart';
import 'package:quran_player/app/theme/app_theme.dart';
import 'package:quran_player/data/audio/providers.dart';
import 'package:quran_player/features/player/playback/fake_audio_playback_engine.dart';
import 'package:quran_player/features/player/state/audio_player_controller.dart';
import 'package:quran_player/features/player/widgets/mini_player.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../_fakes/fake_audio_repository.dart';
import '../../_support/localized.dart';

Future<void> _pump(WidgetTester tester, FakeAudioPlaybackEngine engine) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        audioRepositoryProvider.overrideWithValue(FakeAudioRepository()),
        audioPlaybackEngineProvider.overrideWithValue(engine),
      ],
      child: localized(
        FTheme(
          data: AppTheme.light,
          child: Directionality(
            textDirection: TextDirection.ltr,
            child: Consumer(
              builder: (context, ref, _) => Column(
                children: [
                  FButton(
                    key: const Key('start'),
                    onPress: () => ref
                        .read(audioPlayerControllerProvider.notifier)
                        .startSurah(1),
                    child: const Text('Start'),
                  ),
                  const MiniPlayer(),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  testWidgets(
    'mini player is hidden before playback and appears after queue starts',
    (tester) async {
      await _pump(tester, FakeAudioPlaybackEngine());
      expect(find.byKey(MiniPlayerKeys.root), findsNothing);

      await tester.tap(find.byKey(const Key('start')));
      await tester.pumpAndSettle();

      expect(find.byKey(MiniPlayerKeys.root), findsOneWidget);
      expect(find.byKey(MiniPlayerKeys.title), findsOneWidget);
      expect(find.text('Test Reciter'), findsOneWidget);
    },
  );

  testWidgets('transport buttons act without opening expanded queue', (
    tester,
  ) async {
    await _pump(tester, FakeAudioPlaybackEngine());
    await tester.tap(find.byKey(const Key('start')));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(MiniPlayerKeys.playPause));
    await tester.pump(const Duration(milliseconds: 250));
    expect(find.byKey(MiniPlayerKeys.expanded), findsNothing);
  });
}
