import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../data/quran/providers.dart';
import '../../../domain/quran/quran_source.dart';

final quranSourceProvider = FutureProvider<Result<QuranSource>>((ref) async {
  final repo = ref.watch(quranRepositoryProvider);
  return repo.getSource();
});
