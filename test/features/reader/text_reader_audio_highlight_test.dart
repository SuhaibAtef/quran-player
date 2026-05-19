import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forui/forui.dart';
import 'package:quran_player/app/theme/app_theme.dart';
import 'package:quran_player/data/audio/providers.dart';
import 'package:quran_player/data/quran/providers.dart';
import 'package:quran_player/domain/quran/ayah.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/features/player/playback/fake_audio_playback_engine.dart';
import 'package:quran_player/features/player/state/audio_player_controller.dart';
import 'package:quran_player/features/reader/widgets/text_reader_view.dart';

import '../../_fakes/fake_audio_repository.dart';
import '../../_fakes/fake_quran_repository.dart';
import '../../_support/localized.dart';

Future<void> _pump(WidgetTester tester) async {
  final ayahs = {
    for (var i = 1; i <= 3; i++)
      AyahKey(1, i): Ayah(key: AyahKey(1, i), text: 'ayah $i'),
  };
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        quranRepositoryProvider.overrideWithValue(
          FakeQuranRepository(ayahs: ayahs),
        ),
        audioRepositoryProvider.overrideWithValue(FakeAudioRepository()),
        audioPlaybackEngineProvider.overrideWithValue(
          FakeAudioPlaybackEngine(),
        ),
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
                    key: const Key('start-ayah'),
                    onPress: () => ref
                        .read(audioPlayerControllerProvider.notifier)
                        .startAyah(AyahKey(1, 2)),
                    child: const Text('Start'),
                  ),
                  const Expanded(child: TextReaderView(surahNumber: 1)),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'text reader highlights active playback ayah and clears on stop',
    (tester) async {
      await _pump(tester);

      await tester.tap(find.byKey(const Key('start-ayah')));
      await tester.pumpAndSettle();

      final decorated = tester.widget<Container>(
        find.byKey(TextReaderViewKeys.tile(1, 2)),
      );
      expect(decorated.decoration, isNotNull);

      final context = tester.element(find.byType(TextReaderView));
      final container = ProviderScope.containerOf(context);
      await container.read(audioPlayerControllerProvider.notifier).clear();
      await tester.pumpAndSettle();

      final cleared = tester.widget<Container>(
        find.byKey(TextReaderViewKeys.tile(1, 2)),
      );
      expect(cleared.decoration, isNull);
    },
  );
}
