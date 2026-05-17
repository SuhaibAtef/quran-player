import 'package:flutter/gestures.dart' show PointerDeviceKind;
import 'package:flutter/widgets.dart';

import 'asset_source.dart';
import 'ayah_key.dart';
import 'controller.dart';
import 'decoration.dart';
import 'font_cache.dart';
import 'layout_repository.dart';
import 'models.dart';
import 'result.dart';

/// Stable widget keys exposed for host wiring and tests.
abstract final class MushafViewKeys {
  /// The root of the rendered view.
  static const root = Key('mushaf.view');

  /// The horizontal page pager.
  static const pageView = Key('mushaf.view.page_view');

  /// Shown while a page's font is still loading.
  static const loading = Key('mushaf.view.loading');

  /// Shown when a page's font failed to load.
  static const unavailable = Key('mushaf.view.unavailable');

  /// Key of a rendered page's content. [page] is 1-based.
  static ValueKey<String> page(int page) => ValueKey('mushaf.page.$page');

  /// Key of a rendered line. Both indices are 1-based.
  static ValueKey<String> line(int page, int line) =>
      ValueKey('mushaf.line.$page.$line');

  /// Key of a justified (full-width) line's content.
  static ValueKey<String> justified(int page, int line) =>
      ValueKey('mushaf.justified.$page.$line');

  /// Key of a centered line's content.
  static ValueKey<String> centered(int page, int line) =>
      ValueKey('mushaf.centered.$page.$line');

  /// Key of a rendered word box. [wordId] is `words.id`.
  static ValueKey<String> word(int wordId) => ValueKey('mushaf.word.$wordId');
}

/// Natural glyph size lines are laid out at before the whole page is scaled
/// uniformly to fit the viewport.
const double _kGlyphSize = 28;

/// Natural vertical gap between lines, pre-scale.
const double _kLineGap = 20;

/// Default mushaf "page" colour — a warm parchment. The QPC V4 colour fonts
/// bake their (light-background) tajweed palette into the glyphs, so the page
/// stays a light sheet even under a dark app theme.
const Color _kDefaultPageColor = Color(0xFFFBF7EC);

/// Ink for on-page chrome the consumer does not supply (the default header
/// band, loading/error placeholders). The page is always light, so this is a
/// fixed dark tone rather than a theme colour.
const Color _kOnPageInk = Color(0xFF1B1B1B);

/// Builds the widget for a `surah_name` or `basmallah` line. The engine has no
/// surah names or basmala text of its own — a consumer supplies them here.
/// Returning `null` falls the line back to a plain ornamental band.
typedef MushafHeaderBuilder = Widget? Function(MushafLine line);

/// A mode-agnostic widget that renders printed-mushaf pages.
///
/// `MushafView` renders the page held by its [controller], pages between them
/// right-to-left (swipe, mouse-drag, or a programmatic `controller.openPage`),
/// emits [onWordTap] / [onAyahTap] semantic events, and paints
/// consumer-supplied [decorations] over matching ayahs. It carries no concept
/// of an application "mode" — a consumer wires behaviour onto these events.
class MushafView extends StatefulWidget {
  const MushafView({
    required this.repository,
    required this.assetSource,
    required this.controller,
    this.onWordTap,
    this.onAyahTap,
    this.onPageChanged,
    this.onRenderUnavailable,
    this.decorations = const <MushafDecoration>[],
    this.headerBuilder,
    this.pageColor = _kDefaultPageColor,
    this.palette = 0,
    this.padding = const EdgeInsets.all(16),
    super.key,
  });

  /// The parsed layout the view renders from.
  final MushafLayoutRepository repository;

  /// Supplies the per-page font bytes the view loads lazily.
  final MushafAssetSource assetSource;

  /// Drives which page is shown and exposes navigation.
  final MushafController controller;

  /// Fired when the user taps a rendered word.
  final ValueChanged<MushafWord>? onWordTap;

  /// Fired when the user taps within a rendered ayah.
  final ValueChanged<AyahKey>? onAyahTap;

  /// Fired with the 1-based page number when the visible page changes.
  final ValueChanged<int>? onPageChanged;

  /// Fired when a page's font cannot be loaded — the consumer should degrade.
  final VoidCallback? onRenderUnavailable;

  /// Visual marks painted behind matching ayahs.
  final List<MushafDecoration> decorations;

  /// Renders `surah_name` / `basmallah` lines. When null, those lines fall
  /// back to a plain ornamental band.
  final MushafHeaderBuilder? headerBuilder;

  /// Background colour of the rendered page. Pair this with [palette]: a
  /// light page with a light-text palette, a dark page with a dark-text one.
  final Color pageColor;

  /// `CPAL` palette index the per-page colour fonts render in. 0 is the font's
  /// default (light-background) palette; other indices select dark-background
  /// or plain variants. See `MushafView` / the QUL fonts' palette set.
  final int palette;

  /// Padding between the page edge and the rendered text block.
  final EdgeInsets padding;

  @override
  State<MushafView> createState() => _MushafViewState();
}

class _MushafViewState extends State<MushafView> {
  late final FontCache _fontCache = FontCache(widget.assetSource);
  late final PageController _pageController = PageController(
    initialPage: widget.controller.currentPage - 1,
  );
  bool _renderUnavailableReported = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_syncFromController);
  }

  @override
  void didUpdateWidget(MushafView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_syncFromController);
      widget.controller.addListener(_syncFromController);
      _syncFromController();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromController);
    _pageController.dispose();
    super.dispose();
  }

  /// Animates the pager when the controller's page changes from elsewhere
  /// (a deep link, audio-follow, a nav button).
  void _syncFromController() {
    if (!_pageController.hasClients) return;
    final target = widget.controller.currentPage - 1;
    final current = _pageController.page?.round();
    if (current == target) return;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  void _onPageChanged(int index) {
    final pageNumber = index + 1;
    // `openPage` is a no-op when the controller is already on this page, so a
    // controller-driven animation that fires this callback does not loop.
    widget.controller.openPage(pageNumber);
    widget.onPageChanged?.call(pageNumber);
  }

  void _reportRenderUnavailable() {
    if (_renderUnavailableReported) return;
    _renderUnavailableReported = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onRenderUnavailable?.call();
    });
  }

  @override
  Widget build(BuildContext context) {
    return KeyedSubtree(
      key: MushafViewKeys.root,
      // RTL: a horizontal pager under RTL directionality pages right-to-left —
      // page 1 on the right, the next page entering from the left, the mushaf
      // reading direction. (No `reverse:` — that would cancel it out.)
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: ScrollConfiguration(
          // Re-enable mouse + trackpad drag, which Flutter disables on desktop
          // by default — without it the pager will not swipe on desktop.
          behavior: const _DesktopPagingScrollBehavior(),
          child: PageView.builder(
            key: MushafViewKeys.pageView,
            controller: _pageController,
            itemCount: widget.repository.pageCount,
            onPageChanged: _onPageChanged,
            itemBuilder: (context, index) => _PageContent(
              pageNumber: index + 1,
              repository: widget.repository,
              fontCache: _fontCache,
              decorations: widget.decorations,
              headerBuilder: widget.headerBuilder,
              pageColor: widget.pageColor,
              palette: widget.palette,
              padding: widget.padding,
              onWordTap: widget.onWordTap,
              onAyahTap: widget.onAyahTap,
              onFontUnavailable: _reportRenderUnavailable,
            ),
          ),
        ),
      ),
    );
  }
}

/// Renders one page once its font is available, on the mushaf page colour.
class _PageContent extends StatelessWidget {
  const _PageContent({
    required this.pageNumber,
    required this.repository,
    required this.fontCache,
    required this.decorations,
    required this.headerBuilder,
    required this.pageColor,
    required this.palette,
    required this.padding,
    required this.onWordTap,
    required this.onAyahTap,
    required this.onFontUnavailable,
  });

  final int pageNumber;
  final MushafLayoutRepository repository;
  final FontCache fontCache;
  final List<MushafDecoration> decorations;
  final MushafHeaderBuilder? headerBuilder;
  final Color pageColor;
  final int palette;
  final EdgeInsets padding;
  final ValueChanged<MushafWord>? onWordTap;
  final ValueChanged<AyahKey>? onAyahTap;
  final VoidCallback onFontUnavailable;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: pageColor,
      child: SizedBox.expand(child: _buildPage(context)),
    );
  }

  Widget _buildPage(BuildContext context) {
    final pageResult = repository.page(pageNumber);
    if (pageResult is MushafErr<MushafPage>) {
      return const _Centered(
        key: MushafViewKeys.unavailable,
        child: _OnPageText('Page unavailable'),
      );
    }
    final page = (pageResult as MushafOk<MushafPage>).value;

    return FutureBuilder<MushafResult<String>>(
      future: fontCache.ensure(pageNumber, palette: palette),
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Centered(
            key: MushafViewKeys.loading,
            child: _OnPageText('Loading mushaf page…'),
          );
        }
        final fontResult = snapshot.data;
        if (snapshot.hasError ||
            fontResult == null ||
            fontResult is MushafErr<String>) {
          onFontUnavailable();
          return const _Centered(
            key: MushafViewKeys.unavailable,
            child: _OnPageText('Mushaf page font unavailable'),
          );
        }
        final family = (fontResult as MushafOk<String>).value;
        return _PageBody(
          page: page,
          fontFamily: family,
          decorations: decorations,
          headerBuilder: headerBuilder,
          padding: padding,
          onWordTap: onWordTap,
          onAyahTap: onAyahTap,
        );
      },
    );
  }
}

/// The scaled column of lines for a single page.
class _PageBody extends StatelessWidget {
  const _PageBody({
    required this.page,
    required this.fontFamily,
    required this.decorations,
    required this.headerBuilder,
    required this.padding,
    required this.onWordTap,
    required this.onAyahTap,
  });

  final MushafPage page;
  final String fontFamily;
  final List<MushafDecoration> decorations;
  final MushafHeaderBuilder? headerBuilder;
  final EdgeInsets padding;
  final ValueChanged<MushafWord>? onWordTap;
  final ValueChanged<AyahKey>? onAyahTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Center(
        // The whole page is laid out at a natural size where every justified
        // line shares one text-block width, then scaled uniformly — so the
        // per-page font's pre-justified lines fill the viewport width without
        // per-line scale drift.
        child: FittedBox(
          fit: BoxFit.contain,
          child: KeyedSubtree(
            key: MushafViewKeys.page(page.pageNumber),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Narrower lines (centered ayahs, header bands) center against
              // the widest line — the shared justified text-block width.
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                for (final line in page.lines)
                  Padding(
                    key: MushafViewKeys.line(page.pageNumber, line.lineNumber),
                    padding: const EdgeInsets.symmetric(
                      vertical: _kLineGap / 2,
                    ),
                    child: _LineContent(
                      pageNumber: page.pageNumber,
                      line: line,
                      fontFamily: fontFamily,
                      decorations: decorations,
                      headerBuilder: headerBuilder,
                      onWordTap: onWordTap,
                      onAyahTap: onAyahTap,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// One line: a justified glyph run, a centered glyph run, or a header line.
class _LineContent extends StatelessWidget {
  const _LineContent({
    required this.pageNumber,
    required this.line,
    required this.fontFamily,
    required this.decorations,
    required this.headerBuilder,
    required this.onWordTap,
    required this.onAyahTap,
  });

  final int pageNumber;
  final MushafLine line;
  final String fontFamily;
  final List<MushafDecoration> decorations;
  final MushafHeaderBuilder? headerBuilder;
  final ValueChanged<MushafWord>? onWordTap;
  final ValueChanged<AyahKey>? onAyahTap;

  @override
  Widget build(BuildContext context) {
    if (line.type != MushafLineType.ayah) {
      // surah_name / basmallah lines carry no addressable glyphs — render the
      // consumer's header widget, or a plain ornamental band as a fallback.
      return KeyedSubtree(
        key: MushafViewKeys.centered(pageNumber, line.lineNumber),
        child: headerBuilder?.call(line) ?? const _HeaderBand(),
      );
    }

    final words = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final word in line.words)
          _WordBox(
            word: word,
            fontFamily: fontFamily,
            highlight: _highlightFor(word.ayahKey),
            onTap: () {
              onWordTap?.call(word);
              onAyahTap?.call(word.ayahKey);
            },
          ),
      ],
    );

    if (line.isCentered) {
      return KeyedSubtree(
        key: MushafViewKeys.centered(pageNumber, line.lineNumber),
        child: words,
      );
    }
    return KeyedSubtree(
      key: MushafViewKeys.justified(pageNumber, line.lineNumber),
      child: words,
    );
  }

  Color? _highlightFor(AyahKey ayah) {
    for (final decoration in decorations) {
      if (decoration.ayah == ayah) return decoration.color;
    }
    return null;
  }
}

/// A single tappable word, optionally highlighted by a decoration.
class _WordBox extends StatelessWidget {
  const _WordBox({
    required this.word,
    required this.fontFamily,
    required this.highlight,
    required this.onTap,
  });

  final MushafWord word;
  final String fontFamily;
  final Color? highlight;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      key: MushafViewKeys.word(word.id),
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      // No padding around the glyph run — the per-page font bakes inter-word
      // spacing into its glyph advances, so adjacent words must render
      // edge-to-edge for a justified line to fill its text-block width.
      child: ColoredBox(
        color: highlight ?? const Color(0x00000000),
        child: Text(
          word.text,
          textDirection: TextDirection.rtl,
          // QPC V4 fonts are colour fonts — the glyphs carry their own
          // (tajweed) palette; this colour only applies to any glyph that
          // is not palette-coloured.
          style: TextStyle(
            fontFamily: fontFamily,
            fontSize: _kGlyphSize,
            color: _kOnPageInk,
          ),
        ),
      ),
    );
  }
}

/// Plain ornamental band — the fallback for a `surah_name` / `basmallah` line
/// when the consumer supplies no `headerBuilder`.
class _HeaderBand extends StatelessWidget {
  const _HeaderBand();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _kGlyphSize * 9,
      height: _kGlyphSize * 1.1,
      decoration: BoxDecoration(
        border: Border.all(color: _kOnPageInk.withValues(alpha: 0.45)),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Center(
        child: Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            color: _kOnPageInk.withValues(alpha: 0.45),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

/// Dark-ink text for on-page placeholders (the page is always light).
class _OnPageText extends StatelessWidget {
  const _OnPageText(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    textAlign: TextAlign.center,
    style: const TextStyle(color: _kOnPageInk, fontSize: 14),
  );
}

class _Centered extends StatelessWidget {
  const _Centered({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) => Center(child: child);
}

/// Re-enables mouse + trackpad drag for the pager on desktop.
class _DesktopPagingScrollBehavior extends ScrollBehavior {
  const _DesktopPagingScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => const {
    PointerDeviceKind.touch,
    PointerDeviceKind.mouse,
    PointerDeviceKind.trackpad,
    PointerDeviceKind.stylus,
  };
}
