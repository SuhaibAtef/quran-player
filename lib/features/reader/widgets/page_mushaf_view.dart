// One of exactly two host files permitted to import `package:tarteel_qul/`
// (the other is `lib/data/quran/mushaf_engine.dart`). This widget is the
// page-mode rendering surface; every other layer drives the printed-mushaf
// coordinate system through the framework-free `MushafLocator` contract.
import 'package:flutter/services.dart'
    show KeyDownEvent, KeyEvent, KeyRepeatEvent, LogicalKeyboardKey;
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:forui/forui.dart';
import 'package:tarteel_qul/tarteel_qul.dart' as qul;

import '../../../app/state/mushaf_color_scheme.dart';
import '../../../data/quran/mushaf_engine.dart';
import '../../../data/quran/mushaf_fonts.dart';
import '../../../domain/quran/ayah_key.dart';
import '../../../domain/quran/mushaf_locator.dart';
import '../../../l10n/app_localizations.dart';
import '../../player/state/audio_player_controller.dart';
import 'verse_action_menu.dart';

class PageMushafViewKeys {
  const PageMushafViewKeys._();

  static const root = Key('reader.page_mushaf');
  static const prevButton = Key('reader.page_mushaf.prev');
  static const nextButton = Key('reader.page_mushaf.next');
}

/// Mushaf "page" colours. Light theme renders a warm parchment with a
/// dark-text palette; dark theme a dark sheet with a light-text palette — the
/// glyphs stay legible either way.
const Color _kLightPageColor = Color(0xFFFBF7EC);
const Color _kDarkPageColor = Color(0xFF14110B);

/// Renders the printed mushaf in page mode on top of the `tarteel_qul`
/// engine's [qul.MushafView], adding the desktop affordances the engine leaves
/// to the consumer — keyboard arrow navigation and visible prev/next buttons —
/// and supplying the ornamental surah-header / basmala glyphs and the
/// theme-resolved colour palette.
///
/// **The `package:tarteel_qul/` import here is intentional and load-bearing.**
/// A test guards that no host file outside this widget and
/// `lib/data/quran/mushaf_engine.dart` imports the rendering package directly.
class PageMushafView extends ConsumerStatefulWidget {
  const PageMushafView({
    required this.engine,
    required this.initialPage,
    this.onPageChanged,
    this.onRenderUnavailable,
    super.key,
  });

  /// The opened QUL engine. Must be a non-fallback engine — `repository` and
  /// `assetSource` are read directly.
  final MushafEngine engine;

  /// 1-based page number (1..604) to open on.
  final int initialPage;

  /// Fires with the 1-based page number whenever the visible page changes.
  final ValueChanged<int>? onPageChanged;

  /// Fires when a page font cannot load. The parent reader should degrade to
  /// text mode rather than render blank glyphs.
  final VoidCallback? onRenderUnavailable;

  @override
  ConsumerState<PageMushafView> createState() => _PageMushafViewState();
}

class _PageMushafViewState extends ConsumerState<PageMushafView> {
  late final qul.MushafController _controller = qul.MushafController(
    pageCount: widget.engine.repository!.pageCount,
    initialPage: widget.initialPage,
  );
  final FocusNode _focusNode = FocusNode(debugLabel: 'PageMushafView');

  int? _lastPlaybackPage;

  @override
  void initState() {
    super.initState();
    // The pager opens directly on [initialPage] (the controller's initial
    // page), so its onPageChanged does not fire for it — surface it once so
    // the reader header shows the right page number from the first frame.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) widget.onPageChanged?.call(_controller.currentPage);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  KeyEventResult _handleKey(FocusNode node, KeyEvent event) {
    if (event is! KeyDownEvent && event is! KeyRepeatEvent) {
      return KeyEventResult.ignored;
    }
    // The page is rendered RTL — moving "forward" through the mushaf means
    // moving visually leftward:
    //   ← / Page Down advance to the next page (higher number)
    //   → / Page Up  retreat to the previous page (lower number)
    if (event.logicalKey == LogicalKeyboardKey.arrowLeft ||
        event.logicalKey == LogicalKeyboardKey.pageDown) {
      _controller.next();
      return KeyEventResult.handled;
    }
    if (event.logicalKey == LogicalKeyboardKey.arrowRight ||
        event.logicalKey == LogicalKeyboardKey.pageUp) {
      _controller.previous();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  /// Moves the reader to the active playback ayah's page once per page change.
  void _followPlayback(AyahKey? activeAyah) {
    if (activeAyah == null) return;
    final pageResult = widget.engine.repository!.pageForAyah(
      qul.AyahKey(activeAyah.surah, activeAyah.ayah),
    );
    if (pageResult is! qul.MushafOk<int>) return;
    final page = pageResult.value;
    if (page == _lastPlaybackPage) return;
    _lastPlaybackPage = page;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _controller.openPage(page);
    });
  }

  List<qul.MushafDecoration> _playbackDecorations(
    AyahKey? activeAyah,
    Color highlight,
  ) {
    if (activeAyah == null) return const <qul.MushafDecoration>[];
    return [
      qul.MushafDecoration(
        ayah: qul.AyahKey(activeAyah.surah, activeAyah.ayah),
        color: highlight,
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.theme.colors;
    final scheme = ref.watch(mushafColorSchemeProvider);
    final headerFontsReady =
        ref.watch(mushafHeaderFontsProvider).valueOrNull ?? false;
    final activeAyah = ref.watch(activePlaybackAyahProvider);
    _followPlayback(activeAyah);

    return KeyedSubtree(
      key: PageMushafViewKeys.root,
      child: Focus(
        focusNode: _focusNode,
        autofocus: true,
        onKeyEvent: _handleKey,
        child: Stack(
          children: [
            Positioned.fill(
              child: qul.MushafView(
                repository: widget.engine.repository!,
                assetSource: widget.engine.assetSource!,
                controller: _controller,
                palette: scheme.palette,
                pageColor: scheme.darkPage ? _kDarkPageColor : _kLightPageColor,
                decorations: _playbackDecorations(
                  activeAyah,
                  colors.primary.withValues(alpha: 0.30),
                ),
                headerBuilder: (line) => _mushafHeader(
                  line: line,
                  isDark: scheme.darkPage,
                  fontsReady: headerFontsReady,
                ),
                onPageChanged: (page) {
                  setState(() {});
                  widget.onPageChanged?.call(page);
                },
                onAyahTap: (ayah) => showVerseActionMenu(
                  context,
                  AyahKey(ayah.surah, ayah.ayah),
                ),
                onRenderUnavailable: () => widget.onRenderUnavailable?.call(),
              ),
            ),
            _PageNavOverlay(
              currentPage: _controller.currentPage,
              pageCount: _controller.pageCount,
              onPrev: _controller.previous,
              onNext: _controller.next,
            ),
          ],
        ),
      ),
    );
  }
}

/// Builds a `surah_name` / `basmallah` header line from the QUL header fonts.
/// Returns `null` (engine renders its plain ornamental band) when the
/// surah-header glyph is unavailable.
Widget? _mushafHeader({
  required qul.MushafLine line,
  required bool isDark,
  required bool fontsReady,
}) {
  final ink = isDark ? const Color(0xFFEDE6D2) : const Color(0xFF1B1B1B);

  if (line.type == qul.MushafLineType.basmallah) {
    // The bismillah ligature (U+FDFD); the QUL `quran-common` font carries the
    // mushaf glyph, with the system font as a fallback if it is unavailable.
    return Text(
      bismillahGlyph,
      textDirection: TextDirection.rtl,
      style: TextStyle(
        fontFamily: fontsReady ? quranCommonFamily : null,
        fontSize: 30,
        color: ink,
      ),
    );
  }

  final glyph = surahHeaderGlyph(line.surahNumber ?? 0);
  if (!fontsReady || glyph == null) return null;
  // The ornamental QUL surah-header colour glyph (COLR) — light/dark variant.
  // Sized well above the ayah glyphs so the header reads as a header.
  return Text(
    glyph,
    textDirection: TextDirection.rtl,
    style: TextStyle(
      fontFamily: isDark ? surahHeaderFamilyDark : surahHeaderFamilyLight,
      fontSize: 80,
      color: ink,
    ),
  );
}

class _PageNavOverlay extends StatelessWidget {
  const _PageNavOverlay({
    required this.currentPage,
    required this.pageCount,
    required this.onPrev,
    required this.onNext,
  });

  final int currentPage;
  final int pageCount;
  final VoidCallback onPrev;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    // The mushaf renders RTL: visually, "next page" sits on the LEFT and
    // "previous page" sits on the RIGHT. Mirror the chevrons accordingly.
    final canPrev = currentPage > 1;
    final canNext = currentPage < pageCount;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 24),
      // The mushaf is read right-to-left regardless of the UI locale, so the
      // page nav is pinned LTR: "next" stays on the left and "previous" on
      // the right even when the app chrome is Arabic/RTL.
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Row(
          children: [
            _NavButton(
              buttonKey: PageMushafViewKeys.nextButton,
              icon: FIcons.chevronLeft,
              onPress: canNext ? onNext : null,
              tooltip: AppLocalizations.of(context).readerNextPage,
            ),
            const Spacer(),
            _NavButton(
              buttonKey: PageMushafViewKeys.prevButton,
              icon: FIcons.chevronRight,
              onPress: canPrev ? onPrev : null,
              tooltip: AppLocalizations.of(context).readerPreviousPage,
            ),
          ],
        ),
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

/// A non-interactive preview of mushaf page 1 (Sūrat al-Fātiḥah, opening with
/// āyah 1:1) in the currently selected colour style. Used by the Settings
/// colour-style picker so the user previews a real verse.
class MushafStylePreview extends ConsumerStatefulWidget {
  const MushafStylePreview({required this.engine, super.key});

  /// A non-fallback engine — `repository` / `assetSource` are read directly.
  final MushafEngine engine;

  @override
  ConsumerState<MushafStylePreview> createState() => _MushafStylePreviewState();
}

class _MushafStylePreviewState extends ConsumerState<MushafStylePreview> {
  late final qul.MushafController _controller = qul.MushafController(
    pageCount: widget.engine.repository!.pageCount,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = ref.watch(mushafColorSchemeProvider);
    return IgnorePointer(
      child: qul.MushafView(
        repository: widget.engine.repository!,
        assetSource: widget.engine.assetSource!,
        controller: _controller,
        palette: scheme.palette,
        pageColor: scheme.darkPage ? _kDarkPageColor : _kLightPageColor,
        padding: const EdgeInsets.all(8),
      ),
    );
  }
}

/// Maps an [AyahKey] anchor to a page number via the locator. Returns the
/// anchor's page if known, otherwise falls back to `initialPage`.
int resolveAnchorPage({
  required MushafLocator locator,
  required int initialPage,
  required AyahKey? anchor,
}) {
  if (anchor == null) return initialPage;
  return locator.pageForAyah(anchor).valueOrNull ?? initialPage;
}
