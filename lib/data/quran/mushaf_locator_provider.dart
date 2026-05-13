import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/logger.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/mushaf_locator.dart';
import 'mushaf_locator_qcf.dart';

/// Snapshot of the runtime mushaf-rendering status.
///
/// `locator` is always non-null — it falls through to a [TextOnlyMushafLocator]
/// when the QCF data cannot be initialised. `usingFallback` lets the reader
/// surface a non-fatal banner without re-running the locator.
class MushafLocatorStatus {
  const MushafLocatorStatus({
    required this.locator,
    required this.usingFallback,
  });

  final MushafLocator locator;
  final bool usingFallback;
}

/// Smoke-test constants. Page numbers are properties of the standard 604-page
/// Madani mushaf and are also encoded as `HighlightVerse(surah: 2, verseNumber:
/// 255, page: 42, ...)` in the qcf_quran_plus README example — they double as
/// a tamper detector against accidental data drift in the package.
const int _smokePageForAlFatihah1 = 1;
const int _smokePageForAyatAlKursi = 42;

/// Runs once per launch. Tries the QCF locator; falls back to text-only if
/// init or the smoke test fails. Never throws.
final mushafLocatorProvider = Provider<MushafLocatorStatus>((ref) {
  final created = QcfMushafLocator.create();
  if (created is Err<QcfMushafLocator>) {
    appLogger.warning(
      'Mushaf locator init failed; falling back to text mode: '
      '${created.failure}',
    );
    return const MushafLocatorStatus(
      locator: TextOnlyMushafLocator(),
      usingFallback: true,
    );
  }

  final locator = (created as Ok<QcfMushafLocator>).value;
  final smoke = _smoke(locator);
  if (smoke is Err) {
    appLogger.warning(
      'Mushaf locator smoke test failed; falling back to text mode: '
      '${smoke.failure}',
    );
    return const MushafLocatorStatus(
      locator: TextOnlyMushafLocator(),
      usingFallback: true,
    );
  }

  return MushafLocatorStatus(locator: locator, usingFallback: false);
});

/// Verifies the locator agrees with two well-known mushaf invariants. If the
/// upstream `qcf_quran_plus` data ever silently regresses on these, we degrade
/// rather than render confidently wrong page numbers.
Result<void> _smoke(MushafLocator locator) {
  final page1 = locator.pageForAyah(AyahKey(1, 1));
  if (page1 is Err<int> ||
      (page1 as Ok<int>).value != _smokePageForAlFatihah1) {
    return Result.err(
      _smokeFailure('expected 1:1 → $_smokePageForAlFatihah1, got $page1'),
    );
  }
  final page255 = locator.pageForAyah(AyahKey(2, 255));
  if (page255 is Err<int> ||
      (page255 as Ok<int>).value != _smokePageForAyatAlKursi) {
    return Result.err(
      _smokeFailure('expected 2:255 → $_smokePageForAyatAlKursi, got $page255'),
    );
  }
  final last = locator.firstAyahOnPage(kMushafPageCount);
  if (last is Err<AyahKey>) {
    return Result.err(
      _smokeFailure('expected page $kMushafPageCount populated, got $last'),
    );
  }
  return const Result.ok(null);
}

DataIntegrityFailure _smokeFailure(String message) =>
    DataIntegrityFailure('mushaf locator smoke: $message');
