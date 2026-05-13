import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/material.dart'
    show Colors, MaterialScrollBehavior, PageController;
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:qcf_quran_plus/qcf_quran_plus.dart' as qcf;

import '../../../app/state/tajweed_provider.dart';
import '../../../core/logging/logger.dart';
import '../../../domain/quran/ayah_key.dart';
import '../../../domain/quran/mushaf_locator.dart';
import '../../player/state/audio_player_controller.dart';

typedef PageFontLoader = Future<void> Function(int page);
typedef PagePreloader = Future<void> Function(int page, {int radius});

class PageMushafViewKeys {
  const PageMushafViewKeys._();

  static const root = Key('reader.page_mushaf');
  static const pageView = Key('reader.page_mushaf.page_view');
  static const fontLoading = Key('reader.page_mushaf.font_loading');
  static const prevButton = Key('reader.page_mushaf.prev');
  static const nextButton = Key('reader.page_mushaf.next');
}

/// Wraps `qcf_quran_plus`'s [qcf.QuranPageView] with the project's RTL +
/// theming wiring, plus the desktop affordances the package omits: mouse-drag
/// scrolling, keyboard arrow navigation, and visible prev/next buttons.
///
/// **The package import here is intentional and load-bearing.** A test
/// guards that no other lib/ file imports `qcf_quran_plus` directly; the rest
/// of the app drives the printed-mushaf coordinate system through the
/// framework-free [MushafLocator] contract.
class PageMushafView extends ConsumerStatefulWidget {
  PageMushafView({
    required this.initialPage,
    this.onPageChanged,
    this.onRenderUnavailable,
    PageFontLoader? loadInitialFont,
    PagePreloader? preloadPages,
    super.key,
  }) : loadInitialFont = loadInitialFont ?? qcf.QcfFontLoader.ensureFontLoaded,
       preloadPages = preloadPages ?? qcf.QcfFontLoader.preloadPages;

  /// 1-based page number (1..604).
  final int initialPage;

  /// Fires with the 1-based page number whenever the user swipes.
  final ValueChanged<int>? onPageChanged;

  /// Fires when the visible page's QCF font cannot load. The parent reader
  /// should degrade to text mode instead of rendering blank glyphs.
  final VoidCallback? onRenderUnavailable;

  final PageFontLoader loadInitialFont;
  final PagePreloader preloadPages;

  @override
  ConsumerState<PageMushafView> createState() => _PageMushafViewState();
}

class _PageMushafViewState extends ConsumerState<PageMushafView> {
  /// Pages on each side of the current one to keep font-loaded. Two is enough
  /// to cover a fast swipe — the package's loader caches loaded pages
  /// statically across the process so re-entering the reader is instant.
  static const int _preloadRadius = 2;

  static const _animDuration = Duration(milliseconds: 220);
  static const _animCurve = Curves.easeOutCubic;

  late final PageController _controller = PageController(
    initialPage: (widget.initialPage - 1).clamp(0, kMushafPageCount - 1),
  );
  final FocusNode _focusNode = FocusNode(debugLabel: 'PageMushafView');

  late Future<void> _initialFontReady;
  late int _currentPage = widget.initialPage;
  int? _lastPlaybackPage;

  @override
  void initState() {
    super.initState();
    // The QCF page text uses a per-page font family `QCF4_tajweed_NNN` that
    // is shipped as a zipped TTF in the package's assets. Until the font is
    // extracted and registered with Flutter's FontLoader, Text widgets that
    // reference the family render blank glyphs. Block on the visible page
    // and fire-and-forget the neighbours so swipes don't blank.
    _initialFontReady = _loadInitialFont(widget.initialPage);
    _preloadAround(widget.initialPage);
  }

  Future<void> _loadInitialFont(int page) async {
    try {
      await widget.loadInitialFont(page);
    } catch (e, st) {
      appLogger.warning('QCF font load failed for page $page: $e', e, st);
      if (mounted) widget.onRenderUnavailable?.call();
      rethrow;
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _preloadAround(int page) {
    // Don't await — neighbours load in the background.
    widget.preloadPages(page, radius: _preloadRadius).catchError((
      Object e,
      StackTrace st,
    ) {
      appLogger.fine('QCF preload around $page non-fatal: $e');
    });
  }

  void _onPageChanged(int page) {
    setState(() => _currentPage = page);
    _preloadAround(page);
    widget.onPageChanged?.call(page);
  }

  /// Advances to the next mushaf page (higher number).
  Future<void> _goNext() async {
    if (_currentPage >= kMushafPageCount) return;
    await _controller.nextPage(duration: _animDuration, curve: _animCurve);
  }

  /// Returns to the previous mushaf page (lower number).
  Future<void> _goPrev() async {
    if (_currentPage <= 1) return;
    await _controller.previousPage(duration: _animDuration, curve: _animCurve);
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // The page is rendered RTL — moving "forward" through the mushaf means
    // moving visually leftward. Bind arrow keys to that mental model:
    //   ← advances to the next page (higher number)
    //   → retreats to the previous page (lower number)
    // Page Up / Page Down honour the same forward/back semantics.
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _goNext();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _goPrev();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = context.theme.colors.brightness == Brightness.dark;
    final tajweed = ref.watch(tajweedEnabledProvider);
    final activeAyah = ref.watch(activePlaybackAyahProvider);
    final activePage = _pageFor(activeAyah);
    _schedulePlaybackPage(activePage);
    final highlights = _playbackHighlights(
      context: context,
      activeAyah: activeAyah,
      activePage: activePage,
    );

    return KeyedSubtree(
      key: PageMushafViewKeys.root,
      child: FutureBuilder<void>(
        future: _initialFontReady,
        builder: (context, snap) {
          if (snap.connectionState != ConnectionState.done) {
            return const Center(
              key: PageMushafViewKeys.fontLoading,
              child: SizedBox(
                width: 240,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    FProgress(),
                    SizedBox(height: 12),
                    Text('Loading mushaf page…'),
                  ],
                ),
              ),
            );
          }
          if (snap.hasError) {
            return const SizedBox.shrink();
          }
          return Focus(
            focusNode: _focusNode,
            autofocus: true,
            onKeyEvent: _handleKey,
            child: Stack(
              children: [
                Positioned.fill(
                  // The package's PageView only enables touch+stylus drag by
                  // default, so on desktop the mushaf is stuck. Allow mouse
                  // and trackpad drag to swipe pages.
                  child: ScrollConfiguration(
                    behavior: const _DesktopDragScrollBehavior(),
                    child: qcf.QuranPageView(
                      key: PageMushafViewKeys.pageView,
                      pageController: _controller,
                      highlights: highlights,
                      isDarkMode: isDark,
                      isTajweed: tajweed,
                      pageBackgroundColor: Colors.transparent,
                      onPageChanged: _onPageChanged,
                    ),
                  ),
                ),
                _PageNavOverlay(
                  currentPage: _currentPage,
                  onPrev: _goPrev,
                  onNext: _goNext,
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  int? _pageFor(AyahKey? key) {
    if (key == null) return null;
    try {
      return qcf.getPageNumber(key.surah, key.ayah);
    } on Object catch (e) {
      appLogger.fine('Could not resolve playback ayah page for $key: $e');
      return null;
    }
  }

  List<qcf.HighlightVerse> _playbackHighlights({
    required BuildContext context,
    required AyahKey? activeAyah,
    required int? activePage,
  }) {
    if (activeAyah == null || activePage == null) {
      return const <qcf.HighlightVerse>[];
    }
    return [
      qcf.HighlightVerse(
        surah: activeAyah.surah,
        verseNumber: activeAyah.ayah,
        page: activePage,
        color: context.theme.colors.primary.withValues(alpha: 0.28),
      ),
    ];
  }

  void _schedulePlaybackPage(int? page) {
    if (page == null || page == _lastPlaybackPage) return;
    _lastPlaybackPage = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_controller.hasClients || page == _currentPage) return;
      _controller.animateToPage(
        page - 1,
        duration: _animDuration,
        curve: _animCurve,
      );
    });
  }
}

/// ScrollBehavior that re-enables mouse + trackpad drag, which Flutter
/// disables by default on desktop. Without this the package's `PageView`
/// will not advance to the next page on a desktop swipe gesture.
class _DesktopDragScrollBehavior extends MaterialScrollBehavior {
  const _DesktopDragScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}

class _PageNavOverlay extends StatelessWidget {
  const _PageNavOverlay({
    required this.currentPage,
    required this.onPrev,
    required this.onNext,
  });

  final int currentPage;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    // The mushaf renders RTL: visually, "next page" sits on the LEFT and
    // "previous page" sits on the RIGHT. Mirror the chevrons accordingly so
    // the user reaches forward by tapping the left chevron.
    final canPrev = currentPage > 1;
    final canNext = currentPage < kMushafPageCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      child: Row(
        children: [
          // Forward (advance to higher page number).
          _NavButton(
            buttonKey: PageMushafViewKeys.nextButton,
            icon: FIcons.chevronLeft,
            onPress: canNext ? onNext : null,
            tooltip: 'Next page',
          ),
          const Spacer(),
          // Back (return to lower page number).
          _NavButton(
            buttonKey: PageMushafViewKeys.prevButton,
            icon: FIcons.chevronRight,
            onPress: canPrev ? onPrev : null,
            tooltip: 'Previous page',
          ),
        ],
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.buttonKey,
    required this.icon,
    required this.onPress,
    required this.tooltip,
  });

  final Key buttonKey;
  final IconData icon;
  final VoidCallback? onPress;
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: tooltip,
      button: true,
      child: FButton.icon(
        key: buttonKey,
        variant: FButtonVariant.ghost,
        onPress: onPress,
        child: Icon(icon),
      ),
    );
  }
}

/// Helper that uses the locator to map an [AyahKey] anchor to a page number.
/// Returns the anchor's page if known, otherwise falls back to `initialPage`.
int resolveAnchorPage({
  required MushafLocator locator,
  required int initialPage,
  required AyahKey? anchor,
}) {
  if (anchor == null) return initialPage;
  return locator.pageForAyah(anchor).valueOrNull ?? initialPage;
}
