import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../data/tafsir/providers.dart';
import 'quran_integrity_provider.dart' show QuranIntegrityState;

class TafsirIntegrityStatus {
  const TafsirIntegrityStatus({required this.state, this.failure});

  final QuranIntegrityState state;
  final Failure? failure;

  static const loading = TafsirIntegrityStatus(
    state: QuranIntegrityState.loading,
  );
  static const ok = TafsirIntegrityStatus(state: QuranIntegrityState.ok);

  factory TafsirIntegrityStatus.fatal(Failure failure) =>
      TafsirIntegrityStatus(state: QuranIntegrityState.fatal, failure: failure);
}

final tafsirIntegrityProvider = Provider<TafsirIntegrityStatus>((ref) {
  final async = ref.watch(tafsirBootstrapProvider);
  return async.when(
    loading: () => TafsirIntegrityStatus.loading,
    error: (e, st) => TafsirIntegrityStatus.fatal(
      e is Failure ? e : DataAccessFailure('tafsir bootstrap error: $e'),
    ),
    data: (result) => switch (result) {
      Ok() => TafsirIntegrityStatus.ok,
      Err(:final failure) => TafsirIntegrityStatus.fatal(failure),
    },
  );
});
