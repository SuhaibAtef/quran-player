import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../data/quran/providers.dart';

/// Boot-time status surface used by the router and the data-integrity error
/// screen. Three states: loading, ok, fatal.
enum QuranIntegrityState { loading, ok, fatal }

class QuranIntegrityStatus {
  const QuranIntegrityStatus({required this.state, this.failure});

  final QuranIntegrityState state;
  final Failure? failure;

  static const loading = QuranIntegrityStatus(
    state: QuranIntegrityState.loading,
  );
  static const ok = QuranIntegrityStatus(state: QuranIntegrityState.ok);

  factory QuranIntegrityStatus.fatal(Failure failure) =>
      QuranIntegrityStatus(state: QuranIntegrityState.fatal, failure: failure);
}

final quranIntegrityProvider = Provider<QuranIntegrityStatus>((ref) {
  final async = ref.watch(quranBootstrapProvider);
  return async.when(
    loading: () => QuranIntegrityStatus.loading,
    error: (e, st) => QuranIntegrityStatus.fatal(
      e is Failure ? e : DataAccessFailure('bootstrap error: $e'),
    ),
    data: (result) => switch (result) {
      Ok() => QuranIntegrityStatus.ok,
      Err(:final failure) => QuranIntegrityStatus.fatal(failure),
    },
  );
});
