# tarteel_qul

A Flutter rendering engine for **Tarteel QUL** (Quran Universal Library)
printed-mushaf data. It renders page-by-page mushaf layout, word-by-word glyph
scripts, and per-page fonts — supplied entirely by the consumer.

The package **bundles no QUL data or fonts**. It is asset-agnostic: rendering
data reaches the engine only through a `MushafAssetSource` you implement. A
published `tarteel_qul` therefore redistributes nothing — fonts and databases
are the consuming application's responsibility.

## What it does

- Parses a QUL layout database (`pages` table) joined against a QUL word-script
  database (`words` table) into typed `MushafPage` / `MushafLine` /
  `MushafWord` models.
- Exposes a page↔ayah coordinate API: `pageForAyah`, `firstAyahOnPage`,
  `ayahsOnPage`, `pageForSurah`.
- Renders pages through `MushafView` — a mode-agnostic widget that emits
  `onWordTap` / `onAyahTap` events and accepts ayah-highlight decorations.
- Loads each page's font lazily and caches it for the lifetime of the process.
- Surfaces structured failures (`MushafResult` / `MushafFailure`) rather than
  throwing when a database is malformed or a coordinate is out of range.

## The `MushafAssetSource` contract

A consumer supplies all rendering data through one abstraction:

```dart
abstract class MushafAssetSource {
  Future<Uint8List> layoutDb();          // QUL layout SQLite bytes
  Future<Uint8List> wordDb();            // QUL word-script SQLite bytes
  Future<Uint8List> pageFont(int page);  // pN.ttf bytes — fetched lazily
}
```

Where those bytes come from — Flutter assets, the filesystem, a network
fetch — is entirely your decision. `pageFont` is called lazily, one page at a
time, the first time a page is rendered.

### Which QUL resources to supply

The engine is layout-agnostic — it reads page count and lines-per-page from the
data — but it expects the standard QUL SQLite schema. A typical consumer wires
the **QPC V4** resources from [qul.tarteel.ai](https://qul.tarteel.ai/):

| `MushafAssetSource` method | QUL resource |
|---|---|
| `layoutDb()` | QPC V4 mushaf page-layout database (`pages` table) |
| `wordDb()` | QPC V4 word-by-word glyph-script database (`words` table) |
| `pageFont(n)` | The `pN.ttf` KFGQPC per-page font for page `n` |

The layout `pages` table must carry `page_number`, `line_number`, `line_type`,
`is_centered`, `first_word_id`, `last_word_id`, `surah_number`; the `words`
table must carry `id`, `surah`, `ayah`, `word`, `text`.

## Usage

```dart
import 'package:tarteel_qul/tarteel_qul.dart';

final result = await MushafLayoutRepository.open(myAssetSource);
switch (result) {
  case MushafErr(:final failure):
    // The data is missing/malformed — degrade gracefully.
    break;
  case MushafOk(:final value):
    final repository = value;
    final controller = MushafController(pageCount: repository.pageCount);
    // Render with MushafView(repository: repository,
    //   assetSource: myAssetSource, controller: controller, ...).
}
```

## Try it without QUL data

`package:tarteel_qul/fixtures.dart` ships `DemoMushafAssetSource` — a synthetic
three-page mini-layout drawn with a generated box-glyph stub font (no QUL data).
The [`example/`](example/) app runs entirely on it.

```dart
import 'package:tarteel_qul/fixtures.dart';

final source = DemoMushafAssetSource();
```

## Text correctness

QUL glyphs are **rendering data only**. The glyph-code text on a `MushafWord`
is never canonical Quran text — resolve user-actionable text (copy, search,
audio) from a verified text source keyed by the `AyahKey` that `MushafView`'s
`onAyahTap` emits.
