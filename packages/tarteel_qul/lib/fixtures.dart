/// Synthetic fixtures for trying and testing `tarteel_qul` without QUL data.
///
/// This library is intentionally separate from the engine's main `tarteel_qul`
/// library. It provides [DemoMushafAssetSource] — a [MushafAssetSource] backed
/// by an invented three-page mini-layout and a generated box-glyph stub font —
/// plus the lower-level database builders the package's own tests use. None of
/// it is QUL data.
library;

export 'src/fixtures.dart';
