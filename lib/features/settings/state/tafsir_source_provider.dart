import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/error/result.dart';
import '../../../data/tafsir/providers.dart';
import '../../../domain/tafsir/tafsir_source.dart';

final tafsirSourceProvider = FutureProvider<Result<TafsirSource>>((ref) async {
  final repo = ref.watch(tafsirRepositoryProvider);
  return repo.getSource();
});
