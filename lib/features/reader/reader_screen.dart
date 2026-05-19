import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:go_router/go_router.dart';

import '../../core/error/result.dart';
import '../../data/quran/mushaf_locator_provider.dart';
import '../../data/quran/providers.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/mushaf_locator.dart';
import '../../l10n/app_localizations.dart';
import 'state/reading_position_controller.dart';
import 'widgets/page_mushaf_view.dart';
import 'widgets/text_reader_view.dart';

class ReaderScreenKeys {
  const ReaderScreenKeys._();

  static const root = Key('reader.screen');
  static const titleLabel = Key('reader.screen.title');
  static const back = Key('reader.screen.back');
  static const loading = Key('reader.screen.loading');
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

  /// Set when the QUL engine reports a render failure mid-session. Degrades
  /// page mode to text for this screen without writing the user's preference.
  bool _pageRenderUnavailable = false;

  @override
  void initState() {
    super.initState();
    final t = widget.target;
    _currentPage = t is PageReaderTarget ? t.pageNumber : 1;
  }

  @override
  Widget build(BuildContext context) {
    final target = widget.target;
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
            child: Icon(
              Directionality.of(context) == TextDirection.rtl
                  ? FIcons.chevronRight
                  : FIcons.chevronLeft,
            ),
          ),
        ],
      ),
      child: switch (target) {
        SurahReaderTarget() => KeyedSubtree(
          key: ReaderScreenKeys.textMode,
          child: TextReaderView(
            surahNumber: target.surahNumber,
            anchor: target.anchor,
          ),
        ),
        PageReaderTarget() => _buildPageReader(target),
      },
    );
  }

  Widget _buildPageReader(PageReaderTarget target) {
    final engineAsync = ref.watch(mushafEngineProvider);
    return engineAsync.when(
      loading: () => Center(
        key: ReaderScreenKeys.loading,
        child: SizedBox(
          width: 240,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const FProgress(),
              const SizedBox(height: 12),
              Text(AppLocalizations.of(context).readerPreparingMushaf),
            ],
          ),
        ),
      ),
      // openMushafEngine never throws, so this branch is defensive only.
      error: (_, _) => _textFallback(target, surahFallback: 1),
      data: (engine) {
        if (engine.usingFallback || _pageRenderUnavailable) {
          return _textFallback(
            target,
            surahFallback: _surahForPage(engine.locator, target.pageNumber),
          );
        }
        return KeyedSubtree(
          key: ReaderScreenKeys.pageMode,
          child: PageMushafView(
            engine: engine,
            initialPage: resolveAnchorPage(
              locator: engine.locator,
              initialPage: target.pageNumber,
              anchor: target.anchor,
            ),
            onPageChanged: (page) {
              setState(() => _currentPage = page);
              // Record the page's first ayah as the last-read position.
              // PageMushafView fires this for the initial page too, so open
              // and every page turn are both covered.
              final firstAyah = engine.locator.firstAyahOnPage(page);
              if (firstAyah case Ok(:final value)) {
                ref.read(readingPositionProvider.notifier).record(value);
              }
            },
            onRenderUnavailable: () {
              if (!_pageRenderUnavailable && mounted) {
                setState(() => _pageRenderUnavailable = true);
              }
            },
          ),
        );
      },
    );
  }

  Widget _textFallback(PageReaderTarget target, {required int surahFallback}) {
    return Column(
      children: [
        const _FallbackBanner(),
        Expanded(
          child: KeyedSubtree(
            key: ReaderScreenKeys.textMode,
            child: TextReaderView(
              surahNumber: surahFallback,
              anchor: target.anchor,
            ),
          ),
        ),
      ],
    );
  }
}

/// Resolves which surah opens [pageNumber] so a degrade-to-text fallback lands
/// the user on roughly the right place. Defaults to Al-Fatihah if the locator
/// cannot tell us (a text-only fallback locator).
int _surahForPage(MushafLocator locator, int pageNumber) {
  final first = locator.firstAyahOnPage(pageNumber);
  return first is Ok<AyahKey> ? first.value.surah : 1;
}

class _ReaderTitle extends ConsumerWidget {
  const _ReaderTitle({required this.target, required this.currentPage});

  final ReaderTarget target;
  final int currentPage;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context);
    final small = context.theme.typography.sm;
    if (target is PageReaderTarget) {
      return Text(
        l10n.readerPageTitle(currentPage, kMushafPageCount),
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
            target.anchor != null
                ? l10n.readerSurahAyahTitle(
                    surahNumber,
                    value.nameLatin,
                    target.anchor!.ayah,
                  )
                : l10n.readerSurahTitle(surahNumber, value.nameLatin),
          _ => l10n.readerSurahShortTitle(surahNumber),
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
        title: Text(AppLocalizations.of(context).readerFallbackTitle),
        subtitle: Text(AppLocalizations.of(context).readerFallbackBody),
      ),
    );
  }
}
