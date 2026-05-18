import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';

import '../../../core/error/result.dart';
import '../../../data/quran/providers.dart';
import '../../../domain/quran/ayah.dart';
import '../../../domain/quran/ayah_key.dart';
import '../../player/state/audio_player_controller.dart';
import '../state/reading_position_controller.dart';
import 'verse_action_menu.dart';

class TextReaderViewKeys {
  const TextReaderViewKeys._();

  static const root = Key('reader.text_view');
  static const list = Key('reader.text_view.list');
  static const loading = Key('reader.text_view.loading');
  static const error = Key('reader.text_view.error');

  static Key tile(int surah, int ayah) =>
      ValueKey('reader.text_view.tile.$surah.$ayah');
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
  void initState() {
    super.initState();
    // Record the open position once the first frame is laid out. `ref` is
    // valid here (a live callback) — unlike in `dispose()`.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _recordReadingPosition();
    });
  }

  /// Records the topmost visible ayah as the last-read position. Falls back to
  /// the open anchor, then the surah's first ayah. A safe no-op when `user.db`
  /// is unavailable. Called after first layout and on every scroll settle.
  void _recordReadingPosition() {
    final ayah = _topmostVisibleAyahNumber() ?? widget.anchor?.ayah ?? 1;
    final keyResult = AyahKey.tryNew(widget.surahNumber, ayah);
    if (keyResult case Ok(:final value)) {
      ref.read(readingPositionProvider.notifier).record(value);
    }
  }

  /// The ayah number whose row currently sits at the top of the viewport, or
  /// `null` when no row render box is available (e.g. the list never built).
  int? _topmostVisibleAyahNumber() {
    final self = context.findRenderObject();
    if (self is! RenderBox || !self.attached) return null;
    final viewportTop = self.localToGlobal(Offset.zero).dy;

    int? straddling; // greatest dy at or above the top edge
    double? straddlingDy;
    int? firstBelow; // smallest dy below the top edge
    double? firstBelowDy;

    _itemKeys.forEach((ayah, key) {
      final box = key.currentContext?.findRenderObject();
      if (box is! RenderBox || !box.attached) return;
      final dy = box.localToGlobal(Offset.zero).dy;
      if (dy <= viewportTop + 1) {
        if (straddlingDy == null || dy > straddlingDy!) {
          straddlingDy = dy;
          straddling = ayah;
        }
      } else if (firstBelowDy == null || dy < firstBelowDy!) {
        firstBelowDy = dy;
        firstBelow = ayah;
      }
    });
    return straddling ?? firstBelow;
  }

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
      child: NotificationListener<ScrollEndNotification>(
        onNotification: (_) {
          _recordReadingPosition();
          return false;
        },
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
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => showVerseActionMenu(context, a.key),
            child: Container(
              key: TextReaderViewKeys.tile(a.key.surah, a.key.ayah),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              decoration: active
                  ? BoxDecoration(
                      color: context.theme.colors.primary.withValues(
                        alpha: 0.10,
                      ),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: context.theme.colors.primary),
                    )
                  : null,
              child: Row(
                key: tileKey,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 36,
                    child: Text(
                      '${a.key.ayah}.',
                      textDirection: TextDirection.ltr,
                      textAlign: TextAlign.center,
                      style: context.theme.typography.sm.copyWith(
                        color: context.theme.colors.mutedForeground,
                      ),
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
