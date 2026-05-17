import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel_qul/fixtures.dart';
// FontCache is internal to the engine; the test reaches it directly to reset
// the process-wide font registry between cases.
import 'package:tarteel_qul/src/font_cache.dart';
import 'package:tarteel_qul/tarteel_qul.dart';

/// Wraps an asset source and counts `pageFont` calls per page.
class _CountingAssetSource implements MushafAssetSource {
  _CountingAssetSource(this._delegate);

  final MushafAssetSource _delegate;
  final Map<int, int> fontCalls = <int, int>{};

  @override
  Future<Uint8List> layoutDb() => _delegate.layoutDb();

  @override
  Future<Uint8List> wordDb() => _delegate.wordDb();

  @override
  Future<Uint8List> pageFont(int page) {
    fontCalls[page] = (fontCalls[page] ?? 0) + 1;
    return _delegate.pageFont(page);
  }
}

Finder _linesOnPage(int page) => find.byWidgetPredicate((widget) {
  final key = widget.key;
  return key is ValueKey<String> && key.value.startsWith('mushaf.line.$page.');
});

void main() {
  late MushafLayoutRepository repo;

  setUpAll(() async {
    final result = await MushafLayoutRepository.open(DemoMushafAssetSource());
    repo = (result as MushafOk<MushafLayoutRepository>).value;
  });

  setUp(FontCache.debugClearRegistry);

  Future<_CountingAssetSource> pumpView(
    WidgetTester tester, {
    required MushafController controller,
    ValueChanged<MushafWord>? onWordTap,
    ValueChanged<AyahKey>? onAyahTap,
    List<MushafDecoration> decorations = const [],
    int palette = 0,
  }) async {
    final source = _CountingAssetSource(DemoMushafAssetSource());
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 700,
            child: MushafView(
              repository: repo,
              assetSource: source,
              controller: controller,
              onWordTap: onWordTap,
              onAyahTap: onAyahTap,
              decorations: decorations,
              palette: palette,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return source;
  }

  testWidgets('a page renders its lines once the font is loaded', (
    tester,
  ) async {
    await pumpView(tester, controller: MushafController(pageCount: 3));

    expect(find.byKey(MushafViewKeys.loading), findsNothing);
    expect(find.byKey(MushafViewKeys.unavailable), findsNothing);
    // Page 1 of the demo layout has four lines.
    expect(_linesOnPage(1), findsNWidgets(4));
  });

  testWidgets('a selected palette registers the page font under its variant', (
    tester,
  ) async {
    await pumpView(
      tester,
      controller: MushafController(pageCount: 3),
      palette: 2,
    );

    final text = tester.widget<Text>(
      find.descendant(
        of: find.byKey(MushafViewKeys.word(1)),
        matching: find.byType(Text),
      ),
    );
    // Palette 2 renders under a distinct font family (a re-coloured variant).
    expect(text.style?.fontFamily, 'qul_p1_2');
  });

  testWidgets('tapping a word emits the word and its ayah', (tester) async {
    MushafWord? tappedWord;
    AyahKey? tappedAyah;
    await pumpView(
      tester,
      controller: MushafController(pageCount: 3),
      onWordTap: (w) => tappedWord = w,
      onAyahTap: (a) => tappedAyah = a,
    );

    await tester.tap(find.byKey(MushafViewKeys.word(1)));
    await tester.pump();

    expect(tappedWord, isNotNull);
    expect(tappedWord!.id, 1);
    expect(tappedAyah, const AyahKey(1, 1));
  });

  testWidgets('a supplied decoration renders behind its ayah', (tester) async {
    const highlight = Color(0xFF22CC44);
    await pumpView(
      tester,
      controller: MushafController(pageCount: 3),
      decorations: const [
        MushafDecoration(ayah: AyahKey(1, 1), color: highlight),
      ],
    );

    // Word 1 belongs to ayah 1:1 and is highlighted; word 4 (ayah 1:2) is not.
    final highlighted = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(MushafViewKeys.word(1)),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(highlighted.color, highlight);

    final plain = tester.widget<ColoredBox>(
      find.descendant(
        of: find.byKey(MushafViewKeys.word(4)),
        matching: find.byType(ColoredBox),
      ),
    );
    expect(plain.color.a, 0);
  });

  testWidgets('a page font is fetched at most once across rebuilds', (
    tester,
  ) async {
    final controller = MushafController(pageCount: 3);
    final source = await pumpView(tester, controller: controller);
    expect(source.fontCalls[1], 1);

    // Navigate away and back — page 1 is rebuilt but its font is cached.
    controller.next();
    await tester.pumpAndSettle();
    controller.previous();
    await tester.pumpAndSettle();

    expect(source.fontCalls[1], 1);
  });
}
