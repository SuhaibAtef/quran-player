import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/result.dart';
import '../../data/quran/mushaf_locator_provider.dart';
import '../../data/quran/providers.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/mushaf_locator.dart';
import 'widgets/page_mushaf_view.dart';
import 'widgets/text_reader_view.dart';

class ReaderScreenKeys {
  const ReaderScreenKeys._();

  static const root = Key('reader.screen');
  static const titleLabel = Key('reader.screen.title');
  static const back = Key('reader.screen.back');
  static const fallbackBanner = Key('reader.screen.fallback_banner');
  static const pageMode = Key('reader.screen.mode.page');
  static const textMode = Key('reader.screen.mode.text');
}

/// Whether the reader was opened on a `/reader/page/{n}` URL or a
/// `/reader/surah/{n}` URL. Set by the route — the user's persisted
/// `ReaderMode` does not override it.
sealed class ReaderTarget {
  const ReaderTarget({this.anchor});

  final AyahKey? anchor;
}

class PageReaderTarget extends ReaderTarget {
  const PageReaderTarget({required this.pageNumber, super.anchor});

  final int pageNumber;
}

class SurahReaderTarget extends ReaderTarget {
  const SurahReaderTarget({required this.surahNumber, super.anchor});

  final int surahNumber;
}

class ReaderScreen extends ConsumerStatefulWidget {
  const ReaderScreen({required this.target, super.key});

  final ReaderTarget target;

  @override
  ConsumerState<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends ConsumerState<ReaderScreen> {
  late int _currentPage;
  bool _pageRenderUnavailable = false;

  @override
  void initState() {
    super.initState();
    final t = widget.target;
    _currentPage = t is PageReaderTarget ? t.pageNumber : 1;
  }

  @override
  Widget build(BuildContext context) {
    final locatorStatus = ref.watch(mushafLocatorProvider);
    final target = widget.target;

    final useTextMode =
        target is SurahReaderTarget ||
        (target is PageReaderTarget &&
            (locatorStatus.usingFallback || _pageRenderUnavailable));

    return FScaffold(
      key: ReaderScreenKeys.root,
      header: FHeader.nested(
        title: _ReaderTitle(target: target, currentPage: _currentPage),
        prefixes: [
          FButton.icon(
            key: ReaderScreenKeys.back,
            onPress: () {
              if (Navigator.of(context).canPop()) {
                Navigator.of(context).pop();
              } else {
                context.go('/');
              }
            },
            child: const Icon(FIcons.chevronLeft),
          ),
        ],
      ),
      child: Column(
        children: [
          if (target is PageReaderTarget &&
              (locatorStatus.usingFallback || _pageRenderUnavailable))
            const _FallbackBanner(),
          Expanded(
            child: useTextMode
                ? KeyedSubtree(
                    key: ReaderScreenKeys.textMode,
                    child: TextReaderView(
                      surahNumber: _surahForTextMode(
                        target: target,
                        locator: locatorStatus.locator,
                      ),
                      anchor: target.anchor,
                    ),
                  )
                : KeyedSubtree(
                    key: ReaderScreenKeys.pageMode,
                    child: PageMushafView(
                      initialPage: resolveAnchorPage(
                        locator: locatorStatus.locator,
                        initialPage: (target as PageReaderTarget).pageNumber,
                        anchor: target.anchor,
                      ),
                      onPageChanged: (page) =>
                          setState(() => _currentPage = page),
                      onRenderUnavailable: () {
                        if (!_pageRenderUnavailable && mounted) {
                          setState(() => _pageRenderUnavailable = true);
                        }
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

int _surahForTextMode({
  required ReaderTarget target,
  required MushafLocator locator,
}) {
  if (target is SurahReaderTarget) return target.surahNumber;
  if (target is PageReaderTarget) {
    // Page mode requested but we're degrading — try to land the user on the
    // surah that opens this page; if the locator can't tell us (it's a
    // fallback locator), default to Al-Fatihah.
    final first = locator.firstAyahOnPage(target.pageNumber);
    if (first is Ok<AyahKey>) return first.value.surah;
    return 1;
  }
  return 1;
}

class _ReaderTitle extends ConsumerWidget {
  const _ReaderTitle({required this.target, required this.currentPage});

  final ReaderTarget target;
  final int currentPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final small = context.theme.typography.sm;
    if (target is PageReaderTarget) {
      return Text(
        'Page $currentPage of $kMushafPageCount',
        key: ReaderScreenKeys.titleLabel,
        style: small,
      );
    }
    final surahNumber = (target as SurahReaderTarget).surahNumber;
    final repo = ref.watch(quranRepositoryProvider);
    return FutureBuilder(
      future: repo.getSurah(surahNumber),
      builder: (context, snap) {
        final result = snap.data;
        final label = switch (result) {
          Ok(:final value) =>
            'Surah $surahNumber · ${value.nameLatin}'
                '${target.anchor != null ? ' · Ayah ${target.anchor!.ayah}' : ''}',
          _ => 'Surah $surahNumber',
        };
        return Text(label, key: ReaderScreenKeys.titleLabel, style: small);
      },
    );
  }
}

class _FallbackBanner extends StatelessWidget {
  const _FallbackBanner();

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: ReaderScreenKeys.fallbackBanner,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: FAlert(
        icon: const Icon(FIcons.triangleAlert),
        title: const Text('Mushaf rendering unavailable'),
        subtitle: const Text('Showing plain text. Try restarting the app.'),
      ),
    );
  }
}
