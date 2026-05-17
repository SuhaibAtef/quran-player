import 'dart:typed_data';

/// The sole data contract between a consumer and the `tarteel_qul` engine.
///
/// The engine bundles no QUL data. A consumer supplies the QUL layout database
/// bytes, the QUL word-script database bytes, and per-page font bytes through a
/// `MushafAssetSource` implementation. Where those bytes come from — Flutter
/// assets, the filesystem, a network fetch — is entirely the consumer's
/// decision.
///
/// [pageFont] is called lazily, one page at a time, the first time a page is
/// rendered — a consumer need not have all 604 fonts resident to start.
abstract class MushafAssetSource {
  /// Raw bytes of the QUL layout SQLite database (the `pages` table).
  Future<Uint8List> layoutDb();

  /// Raw bytes of the QUL word-script SQLite database (the `words` table).
  Future<Uint8List> wordDb();

  /// Raw bytes of the `pN.ttf` font for the given 1-based [page].
  ///
  /// Called lazily, once per page; the engine caches the registered font for
  /// the lifetime of the process.
  Future<Uint8List> pageFont(int page);
}
