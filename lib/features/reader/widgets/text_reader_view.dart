import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/error/result.dart';
import '../../../data/quran/providers.dart';
import '../../../domain/quran/ayah.dart';
import '../../../domain/quran/ayah_key.dart';
import '../../player/state/audio_player_controller.dart';

class TextReaderViewKeys {
  const TextReaderViewKeys._();

  static const root = Key('reader.text_view');
  static const list = Key('reader.text_view.list');
  static const loading = Key('reader.text_view.loading');
  static const error = Key('reader.text_view.error');

  static Key tile(int surah, int ayah) =>
      ValueKey('reader.text_view.tile.$surah.$ayah');

  static Key play(int surah, int ayah) =>
      ValueKey('reader.text_view.play.$surah.$ayah');
}

class TextReaderView extends ConsumerStatefulWidget {
  const TextReaderView({required this.surahNumber, this.anchor, super.key});

  /// 1-based surah number (1..114).
  final int surahNumber;

  /// Optional ayah to scroll into view on first build.
  final AyahKey? anchor;

  @override
  ConsumerState<TextReaderView> createState() => _TextReaderViewState();
}

class _TextReaderViewState extends ConsumerState<TextReaderView> {
  final _itemKeys = <int, GlobalKey>{};
  bool _scrollScheduled = false;
  AyahKey? _lastPlaybackScroll;

  @override
  Widget build(BuildContext context) {
    ref.listen<AyahKey?>(activePlaybackAyahProvider, (_, active) {
      _schedulePlaybackScroll(active);
    });
    _schedulePlaybackScroll(ref.watch(activePlaybackAyahProvider));

    final repo = ref.watch(quranRepositoryProvider);
    final future = repo.getSurahAyahs(widget.surahNumber);

    return KeyedSubtree(
      key: TextReaderViewKeys.root,
      child: FutureBuilder<Result<List<Ayah>>>(
        future: future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(
              key: TextReaderViewKeys.loading,
              child: FProgress(),
            );
          }
          final result = snapshot.data;
          if (result == null) {
            return _ErrorState(message: 'No data');
          }
          return switch (result) {
            Ok(:final value) => _AyahList(
              surahNumber: widget.surahNumber,
              ayahs: value,
              anchor: widget.anchor,
              itemKeys: _itemKeys,
              onListReady: _scheduleAnchorScroll,
            ),
            Err(:final failure) => _ErrorState(message: failure.message),
          };
        },
      ),
    );
  }

  void _scheduleAnchorScroll() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    final anchor = widget.anchor;
    if (anchor == null || anchor.surah != widget.surahNumber) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final key = _itemKeys[anchor.ayah];
      final ctx = key?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        alignment: 0.1,
      );
    });
  }

  void _schedulePlaybackScroll(AyahKey? active) {
    if (active == null || active.surah != widget.surahNumber) return;
    if (_lastPlaybackScroll == active) return;
    _lastPlaybackScroll = active;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final key = _itemKeys[active.ayah];
      final ctx = key?.currentContext;
      if (ctx == null) return;
      Scrollable.ensureVisible(
        ctx,
        duration: const Duration(milliseconds: 220),
        alignment: 0.18,
      );
    });
  }
}

class _AyahList extends ConsumerWidget {
  const _AyahList({
    required this.surahNumber,
    required this.ayahs,
    required this.anchor,
    required this.itemKeys,
    required this.onListReady,
  });

  final int surahNumber;
  final List<Ayah> ayahs;
  final AyahKey? anchor;
  final Map<int, GlobalKey> itemKeys;
  final VoidCallback onListReady;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    onListReady();
    final activeAyah = ref.watch(activePlaybackAyahProvider);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView.builder(
        key: TextReaderViewKeys.list,
        itemCount: ayahs.length,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        itemBuilder: (context, i) {
          final a = ayahs[i];
          final tileKey = itemKeys.putIfAbsent(a.key.ayah, GlobalKey.new);
          final active = activeAyah == a.key;
          return Container(
            key: TextReaderViewKeys.tile(a.key.surah, a.key.ayah),
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
            decoration: active
                ? BoxDecoration(
                    color: context.theme.colors.primary.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: context.theme.colors.primary),
                  )
                : null,
            child: Row(
              key: tileKey,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: 76,
                  child: Row(
                    textDirection: TextDirection.ltr,
                    children: [
                      FButton(
                        key: TextReaderViewKeys.play(a.key.surah, a.key.ayah),
                        variant: FButtonVariant.ghost,
                        onPress: () => ref
                            .read(audioPlayerControllerProvider.notifier)
                            .startAyah(a.key),
                        child: const Icon(FIcons.play),
                      ),
                      Expanded(
                        child: Text(
                          '${a.key.ayah}.',
                          textDirection: TextDirection.ltr,
                          textAlign: TextAlign.end,
                          style: context.theme.typography.sm,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    a.text,
                    textDirection: TextDirection.rtl,
                    textAlign: TextAlign.right,
                    style: context.theme.typography.lg.copyWith(height: 2.0),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: TextReaderViewKeys.error,
      padding: const EdgeInsets.all(24),
      child: FAlert(
        title: const Text("Couldn't load ayahs"),
        subtitle: Text(message),
      ),
    );
  }
}
