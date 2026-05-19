import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:tarteel_qul/fixtures.dart';
import 'package:tarteel_qul/tarteel_qul.dart';

/// A [MushafAssetSource] backed by explicit byte buffers — lets a test pair a
/// healthy database with a malformed one.
class _BytesAssetSource implements MushafAssetSource {
  _BytesAssetSource({
    required this.layout,
    required this.words,
    Uint8List? font,
  }) : font = font ?? demoStubFontBytes();

  final Uint8List layout;
  final Uint8List words;
  final Uint8List font;

  @override
  Future<Uint8List> layoutDb() async => layout;

  @override
  Future<Uint8List> wordDb() async => words;

  @override
  Future<Uint8List> pageFont(int page) async => font;
}

void main() {
  group('MushafLayoutRepository.open — demo layout', () {
    late MushafLayoutRepository repo;

    setUpAll(() async {
      final result = await MushafLayoutRepository.open(DemoMushafAssetSource());
      repo = (result as MushafOk<MushafLayoutRepository>).value;
    });

    test('derives page count and lines-per-page from the pages table', () {
      expect(repo.pageCount, 3);
      expect(repo.linesPerPage, 5);
    });

    test('a page resolves to ordered typed lines', () {
      final page = (repo.page(1) as MushafOk<MushafPage>).value;
      expect(page.pageNumber, 1);
      expect(page.lines.map((l) => l.lineNumber), [1, 2, 3, 4]);
      expect(page.lines.first.type, MushafLineType.surahName);
      expect(page.lines.first.isCentered, isTrue);
      expect(page.lines.first.surahNumber, 1);
      expect(page.lines[1].type, MushafLineType.ayah);
    });

    test('ayah lines carry their joined words with coordinates', () {
      final page = (repo.page(1) as MushafOk<MushafPage>).value;
      final firstAyahLine = page.lines[1];
      expect(firstAyahLine.words.map((w) => w.id), [1, 2, 3]);
      expect(
        firstAyahLine.words.every((w) => w.surah == 1 && w.ayah == 1),
        isTrue,
      );
      expect(firstAyahLine.words.first.text, isNotEmpty);
    });

    test('a basmallah line carries no words and no surah number', () {
      final page = (repo.page(2) as MushafOk<MushafPage>).value;
      final basmallah = page.lines[1];
      expect(basmallah.type, MushafLineType.basmallah);
      expect(basmallah.words, isEmpty);
      expect(basmallah.surahNumber, isNull);
    });

    test('coordinate round-trip for a known ayah', () {
      expect((repo.pageForAyah(const AyahKey(1, 1)) as MushafOk<int>).value, 1);
      expect(
        (repo.firstAyahOnPage(1) as MushafOk<AyahKey>).value,
        const AyahKey(1, 1),
      );
    });

    test('ayahsOnPage returns a non-empty ordered list', () {
      final ayahs = (repo.ayahsOnPage(1) as MushafOk<List<AyahKey>>).value;
      expect(ayahs, const [AyahKey(1, 1), AyahKey(1, 2), AyahKey(1, 3)]);
    });

    test('firstAyahOnPage on a continuation page', () {
      expect(
        (repo.firstAyahOnPage(3) as MushafOk<AyahKey>).value,
        const AyahKey(2, 4),
      );
    });

    test('pageForSurah equals pageForAyah of the surah\'s first ayah', () {
      final viaSurah = (repo.pageForSurah(2) as MushafOk<int>).value;
      final viaAyah =
          (repo.pageForAyah(const AyahKey(2, 1)) as MushafOk<int>).value;
      expect(viaSurah, viaAyah);
      expect(viaSurah, 2);
    });

    test(
      'out-of-range coordinate input fails structurally, not by throwing',
      () {
        final ayah = repo.pageForAyah(const AyahKey(99, 1));
        expect(ayah, isA<MushafErr<int>>());
        expect(
          (ayah as MushafErr<int>).failure.kind,
          MushafFailureKind.outOfRange,
        );

        final page = repo.firstAyahOnPage(700);
        expect(page, isA<MushafErr<AyahKey>>());
        expect(
          (page as MushafErr<AyahKey>).failure.kind,
          MushafFailureKind.outOfRange,
        );
      },
    );
  });

  group('MushafLayoutRepository.open — validation', () {
    test(
      'a layout DB missing the pages table fails with a schema failure',
      () async {
        final source = _BytesAssetSource(
          layout: await buildRawDbBytes(['CREATE TABLE not_pages(x INTEGER)']),
          words: await buildDemoWordDb(),
        );
        final result = await MushafLayoutRepository.open(source);
        expect(result, isA<MushafErr<MushafLayoutRepository>>());
        expect(
          (result as MushafErr<MushafLayoutRepository>).failure.kind,
          MushafFailureKind.schema,
        );
      },
    );

    test(
      'a word DB missing the words table fails with a schema failure',
      () async {
        final source = _BytesAssetSource(
          layout: await buildDemoLayoutDb(),
          words: await buildRawDbBytes(['CREATE TABLE not_words(x INTEGER)']),
        );
        final result = await MushafLayoutRepository.open(source);
        expect(result, isA<MushafErr<MushafLayoutRepository>>());
        expect(
          (result as MushafErr<MushafLayoutRepository>).failure.kind,
          MushafFailureKind.schema,
        );
      },
    );

    test(
      'a non-database blob fails structurally rather than throwing',
      () async {
        final source = _BytesAssetSource(
          layout: Uint8List.fromList([1, 2, 3, 4, 5]),
          words: await buildDemoWordDb(),
        );
        final result = await MushafLayoutRepository.open(source);
        expect(result, isA<MushafErr<MushafLayoutRepository>>());
      },
    );
  });
}
