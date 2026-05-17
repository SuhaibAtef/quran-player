import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show FontLoader;

import 'asset_source.dart';
import 'cpal.dart';
import 'result.dart';

/// The font family a page's glyphs are registered and rendered under.
/// Distinct per [palette] so a re-coloured variant does not collide.
String mushafFontFamily(int page, [int palette = 0]) =>
    palette == 0 ? 'qul_p$page' : 'qul_p${page}_$palette';

/// Lazily loads and registers per-page mushaf fonts.
///
/// A page's `pN.ttf` is fetched from the [MushafAssetSource] the first time
/// the page is rendered, optionally re-coloured to a chosen `CPAL` palette,
/// registered with Flutter's [FontLoader], then cached for the lifetime of the
/// process — the registration cache is static, keyed by `(page, palette)`, so
/// re-entering a reader does not re-fetch a font already loaded. Internal to
/// the engine; consumers reach it only through `MushafView`.
class FontCache {
  FontCache(this._source);

  final MushafAssetSource _source;

  /// Keyed by `"page:palette"`, shared across every [FontCache] instance so a
  /// variant is fetched, re-coloured, and registered at most once per process.
  static final Map<String, Future<MushafResult<String>>> _registry =
      <String, Future<MushafResult<String>>>{};

  /// Ensures the font for [page] in [palette] is registered, returning its
  /// family name on success or a structured failure if the bytes could not be
  /// fetched or the font could not be parsed.
  Future<MushafResult<String>> ensure(int page, {int palette = 0}) =>
      _registry.putIfAbsent('$page:$palette', () => _load(page, palette));

  Future<MushafResult<String>> _load(int page, int palette) async {
    try {
      var bytes = await _source.pageFont(page);
      if (palette != 0) bytes = selectCpalPalette(bytes, palette);
      final family = mushafFontFamily(page, palette);
      final loader = FontLoader(family)
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      return MushafResult.ok(family);
    } catch (e) {
      // A failed load must not poison the cache — drop the entry so a later
      // attempt can retry — and surface the failure structurally.
      _registry.remove('$page:$palette');
      return MushafResult.err(
        MushafFailure(
          MushafFailureKind.dataAccess,
          'failed to load font for page $page (palette $palette): $e',
        ),
      );
    }
  }

  /// Clears the process-wide registration cache. For tests that assert lazy,
  /// once-per-variant loading without cross-test bleed.
  @visibleForTesting
  static void debugClearRegistry() => _registry.clear();
}
