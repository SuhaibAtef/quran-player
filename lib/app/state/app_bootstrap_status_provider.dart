import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import 'quran_integrity_provider.dart';
import 'tafsir_integrity_provider.dart';

/// Composite boot status — folds every bundled-dataset integrity check into
/// one signal the router and the error screen consume.
///
/// Loading: any underlying dataset is still verifying.
/// Fatal:   any underlying dataset failed; carries which one in [failingDataset]
///          and the wrapped [failure].
/// Ok:      every dataset passed.
enum AppBootstrapState { loading, ok, fatal }

class AppBootstrapStatus {
  const AppBootstrapStatus({
    required this.state,
    this.failure,
    this.failingDataset,
  });

  final AppBootstrapState state;
  final Failure? failure;

  /// Human-friendly dataset name surfaced on the error screen so users can
  /// distinguish a Quran integrity failure from a tafsir one without reading
  /// the message body.
  final String? failingDataset;

  static const loading = AppBootstrapStatus(state: AppBootstrapState.loading);
  static const ok = AppBootstrapStatus(state: AppBootstrapState.ok);

  factory AppBootstrapStatus.fatal({
    required Failure failure,
    required String dataset,
  }) => AppBootstrapStatus(
    state: AppBootstrapState.fatal,
    failure: failure,
    failingDataset: dataset,
  );
}

final appBootstrapStatusProvider = Provider<AppBootstrapStatus>((ref) {
  final quran = ref.watch(quranIntegrityProvider);
  // Quran is the prerequisite for tafsir — surface its failures first so the
  // error screen names the root cause rather than the cascaded tafsir error.
  switch (quran.state) {
    case QuranIntegrityState.loading:
      return AppBootstrapStatus.loading;
    case QuranIntegrityState.fatal:
      return AppBootstrapStatus.fatal(
        failure: quran.failure ?? DataAccessFailure('Quran bootstrap failed'),
        dataset: 'Quran',
      );
    case QuranIntegrityState.ok:
      break;
  }

  final tafsir = ref.watch(tafsirIntegrityProvider);
  switch (tafsir.state) {
    case QuranIntegrityState.loading:
      return AppBootstrapStatus.loading;
    case QuranIntegrityState.fatal:
      return AppBootstrapStatus.fatal(
        failure: tafsir.failure ?? DataAccessFailure('Tafsir bootstrap failed'),
        dataset: 'Tafsir',
      );
    case QuranIntegrityState.ok:
      return AppBootstrapStatus.ok;
  }
});
