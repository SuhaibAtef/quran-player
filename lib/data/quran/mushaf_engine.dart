// One of exactly two host files permitted to import `package:tarteel_qul/`
// (the other is `lib/features/reader/widgets/page_mushaf_view.dart`). This
// file is the host↔engine adapter: it bundles the QUL assets into a
// `MushafAssetSource`, opens the engine, and adapts its coordinate API to the
// framework-free `MushafLocator` contract. Every other layer drives the
// printed-mushaf coordinate system through `MushafLocator` and the opaque
// `MushafEngine` handle — never `package:tarteel_qul/` directly.
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show AssetBundle, ByteData;
import 'package:tarteel_qul/tarteel_qul.dart' as qul;

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/logger.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/mushaf_locator.dart';

/// Bundled QUL asset paths — declared as Flutter assets in `pubspec.yaml`,
/// downloaded by a contributor into the gitignored `assets/qul/` directory.
const String qulLayoutDbAsset = 'assets/qul/qpc-v4-tajweed-15-lines.db';
const String qulWordDbAsset = 'assets/qul/qpc-v4.db';
const String qulFontZipAsset = 'assets/qul/ttf.zip';

/// A `tarteel_qul` [qul.MushafAssetSource] backed by the bundled Flutter
/// assets: the layout + word databases are loaded directly; per-page fonts are
/// unzipped on demand from `ttf.zip`.
class BundledMushafAssetSource implements qul.MushafAssetSource {
  BundledMushafAssetSource(this._bundle);

  final AssetBundle _bundle;

  /// `ttf.zip` is decoded once and held resident; individual `pN.ttf` entries
  /// are decompressed lazily, one page at a time.
  Archive? _fontArchive;

  @override
  Future<Uint8List> layoutDb() => _loadAsset(qulLayoutDbAsset);

  @override
  Future<Uint8List> wordDb() => _loadAsset(qulWordDbAsset);

  @override
  Future<Uint8List> pageFont(int page) async {
    final archive = _fontArchive ??= ZipDecoder().decodeBytes(
      await _loadAsset(qulFontZipAsset),
    );
    final entry = archive.findFile('p$page.ttf');
    if (entry == null) {
      throw StateError('$qulFontZipAsset has no p$page.ttf');
    }
    final bytes = entry.readBytes();
    if (bytes == null) {
      throw StateError('p$page.ttf in $qulFontZipAsset is empty');
    }
    return bytes;
  }

  Future<Uint8List> _loadAsset(String assetPath) async {
    final ByteData data = await _bundle.load(assetPath);
    return data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
  }
}

/// A [MushafLocator] backed by the `tarteel_qul` engine's coordinate API.
///
/// It translates the engine's `tarteel_qul`-namespaced coordinate types and
/// structured failures into the host's framework-free `AyahKey` / `Result` /
/// `Failure` vocabulary, so every downstream consumer keeps depending only on
/// `MushafLocator`.
class QulMushafLocator implements MushafLocator {
  QulMushafLocator(this._repository);

  final qul.MushafLayoutRepository _repository;

  @override
  Result<int> pageForAyah(AyahKey key) =>
      _adapt(_repository.pageForAyah(qul.AyahKey(key.surah, key.ayah)));

  @override
  Result<AyahKey> firstAyahOnPage(int page) {
    final result = _repository.firstAyahOnPage(page);
    return switch (result) {
      qul.MushafOk(:final value) => _toHostKey(value),
      qul.MushafErr(:final failure) => Result.err(_toFailure(failure)),
    };
  }

  @override
  Result<List<AyahKey>> ayahsOnPage(int page) {
    final result = _repository.ayahsOnPage(page);
    return switch (result) {
      qul.MushafOk(:final value) => _toHostKeys(value),
      qul.MushafErr(:final failure) => Result.err(_toFailure(failure)),
    };
  }

  @override
  Result<int> pageForSurah(int surahNumber) {
    if (surahNumber < 1 || surahNumber > 114) {
      return Result.err(
        InvalidInputFailure('surah out of range: $surahNumber'),
      );
    }
    return _adapt(_repository.pageForSurah(surahNumber));
  }

  Result<int> _adapt(qul.MushafResult<int> result) => switch (result) {
    qul.MushafOk(:final value) => Result.ok(value),
    qul.MushafErr(:final failure) => Result.err(_toFailure(failure)),
  };

  Result<AyahKey> _toHostKey(qul.AyahKey key) {
    final host = AyahKey.tryNew(key.surah, key.ayah);
    return switch (host) {
      Ok(:final value) => Result.ok(value),
      Err(:final failure) => Result.err(
        DataIntegrityFailure(
          'engine produced an invalid coordinate '
          '${key.surah}:${key.ayah}: ${failure.message}',
        ),
      ),
    };
  }

  Result<List<AyahKey>> _toHostKeys(List<qul.AyahKey> keys) {
    final converted = <AyahKey>[];
    for (final key in keys) {
      final host = _toHostKey(key);
      if (host is Err<AyahKey>) return Result.err(host.failure);
      converted.add((host as Ok<AyahKey>).value);
    }
    return Result.ok(List<AyahKey>.unmodifiable(converted));
  }

  /// Maps an engine failure onto the host failure taxonomy. An out-of-range
  /// coordinate is invalid *input*; a schema or access fault is a *data*
  /// problem the reader degrades on.
  Failure _toFailure(qul.MushafFailure failure) => switch (failure.kind) {
    qul.MushafFailureKind.outOfRange => InvalidInputFailure(failure.message),
    qul.MushafFailureKind.schema => DataIntegrityFailure(failure.message),
    qul.MushafFailureKind.dataAccess => DataAccessFailure(failure.message),
  };
}

/// No-op locator used when QUL page rendering is unavailable. Every call
/// returns [UnsupportedFailure] so callers fold to text-mode rendering without
/// ever throwing across the boundary.
class TextOnlyMushafLocator implements MushafLocator {
  const TextOnlyMushafLocator();

  static const _failure = UnsupportedFailure(
    'mushaf rendering unavailable (text-only fallback)',
  );

  @override
  Result<int> pageForAyah(AyahKey key) => Result.err(_failure);

  @override
  Result<AyahKey> firstAyahOnPage(int page) => Result.err(_failure);

  @override
  Result<List<AyahKey>> ayahsOnPage(int page) => Result.err(_failure);

  @override
  Result<int> pageForSurah(int surahNumber) => Result.err(_failure);
}

/// The runtime mushaf-rendering handle the reader branches on.
///
/// [locator] is always non-null. When [usingFallback] is true, QUL page
/// rendering is unavailable: [locator] is a [TextOnlyMushafLocator] and
/// [repository] / [assetSource] are null. When false, the reader may render
/// page mode from [repository] + [assetSource].
class MushafEngine {
  const MushafEngine._({
    required this.locator,
    required this.usingFallback,
    this.repository,
    this.assetSource,
  });

  /// The degraded, text-only engine — QUL page rendering unavailable. The
  /// reader branches on `usingFallback` to stay in text mode for the session.
  const MushafEngine.unavailable()
    : locator = const TextOnlyMushafLocator(),
      usingFallback = true,
      repository = null,
      assetSource = null;

  /// Builds a non-fallback engine over an already-opened repository — for
  /// widget tests that drive `PageMushafView` from a fixture layout.
  @visibleForTesting
  MushafEngine.forTest({
    required qul.MushafLayoutRepository repository,
    required qul.MushafAssetSource assetSource,
  }) : this._(
         locator: QulMushafLocator(repository),
         usingFallback: false,
         repository: repository,
         assetSource: assetSource,
       );

  final MushafLocator locator;
  final bool usingFallback;

  /// The parsed QUL layout — non-null only when [usingFallback] is false.
  final qul.MushafLayoutRepository? repository;

  /// The QUL asset source — non-null only when [usingFallback] is false.
  final qul.MushafAssetSource? assetSource;
}

/// Opens the QUL mushaf engine from the bundled assets and validates it.
///
/// Progressive enhancement, never fail-closed: any failure — missing assets,
/// a schema mismatch, a wrong page count, a failed smoke test — degrades to a
/// text-only [MushafEngine] rather than throwing. This never triggers the
/// data-integrity fatal screen.
Future<MushafEngine> openMushafEngine(AssetBundle bundle) async {
  try {
    final source = BundledMushafAssetSource(bundle);
    final opened = await qul.MushafLayoutRepository.open(source);
    if (opened is qul.MushafErr<qul.MushafLayoutRepository>) {
      appLogger.warning(
        'Mushaf engine: QUL layout failed to open; degrading to text mode: '
        '${opened.failure}',
      );
      return _fallbackEngine();
    }
    final repository =
        (opened as qul.MushafOk<qul.MushafLayoutRepository>).value;

    // Structural validation: the standard Madani mushaf is exactly 604 pages.
    if (repository.pageCount != kMushafPageCount) {
      appLogger.warning(
        'Mushaf engine: QUL layout reports ${repository.pageCount} pages '
        '(expected $kMushafPageCount); degrading to text mode',
      );
      return _fallbackEngine();
    }

    final locator = QulMushafLocator(repository);
    final smoke = _smokeTest(locator);
    if (smoke is Err<void>) {
      appLogger.warning(
        'Mushaf engine: smoke test failed; degrading to text mode: '
        '${smoke.failure}',
      );
      return _fallbackEngine();
    }

    appLogger.info('Mushaf engine: QUL layout ready (604 pages)');
    return MushafEngine._(
      locator: locator,
      usingFallback: false,
      repository: repository,
      assetSource: source,
    );
  } catch (e, st) {
    appLogger.warning('Mushaf engine: unexpected open failure: $e', e, st);
    return _fallbackEngine();
  }
}

MushafEngine _fallbackEngine() => const MushafEngine.unavailable();

/// Smoke-test page numbers — ground-truth invariants of the standard 604-page
/// Madani mushaf. If the QUL data ever regresses on these we degrade rather
/// than render confidently wrong page numbers.
const int _smokePageForAlFatihah1 = 1;
const int _smokePageForAyatAlKursi = 42;

Result<void> _smokeTest(MushafLocator locator) {
  final page1 = locator.pageForAyah(AyahKey(1, 1));
  if (page1 is Err<int> ||
      (page1 as Ok<int>).value != _smokePageForAlFatihah1) {
    return Result.err(
      DataIntegrityFailure(
        'expected 1:1 -> $_smokePageForAlFatihah1, '
        'got $page1',
      ),
    );
  }
  final page255 = locator.pageForAyah(AyahKey(2, 255));
  if (page255 is Err<int> ||
      (page255 as Ok<int>).value != _smokePageForAyatAlKursi) {
    return Result.err(
      DataIntegrityFailure(
        'expected 2:255 -> $_smokePageForAyatAlKursi, '
        'got $page255',
      ),
    );
  }
  final last = locator.firstAyahOnPage(kMushafPageCount);
  if (last is Err<AyahKey>) {
    return Result.err(
      DataIntegrityFailure(
        'expected page $kMushafPageCount populated, '
        'got $last',
      ),
    );
  }
  return const Result.ok(null);
}
