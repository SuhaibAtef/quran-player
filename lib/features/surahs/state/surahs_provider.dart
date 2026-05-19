import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../data/quran/providers.dart';
import '../../../domain/quran/surah.dart';

/// Loads the full surah list from the repository. Returns a `Result` so the
/// UI can fold ok/err without double-wrapping `AsyncValue` and `Result`.
final surahsProvider = FutureProvider<Result<List<Surah>>>((ref) async {
  final repo = ref.watch(quranRepositoryProvider);
  return repo.listSurahs();
});
