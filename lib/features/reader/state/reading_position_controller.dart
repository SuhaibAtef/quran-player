import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/user_db_provider.dart';
import '../../../domain/quran/ayah_key.dart';
import '../../../domain/reading/reading_position.dart';

/// The user's last-read reading position.
///
/// Resolves to `null` when nothing has been recorded yet or `user.db` is
/// unavailable — the Home resume entry point is simply absent in both cases.
final readingPositionProvider =
    AsyncNotifierProvider<ReadingPositionController, ReadingPosition?>(
      ReadingPositionController.new,
    );

class ReadingPositionController extends AsyncNotifier<ReadingPosition?> {
  @override
  Future<ReadingPosition?> build() async {
    final repo = ref.watch(readingPositionRepositoryProvider);
    if (repo == null) return null;
    return (await repo.load()).valueOrNull;
  }

  /// Records [key] as the most recent reading position: updates in-memory
  /// state immediately so the resume entry point reflects it, and persists to
  /// `user.db` in the background. A safe no-op when `user.db` is unavailable.
  void record(AyahKey key) {
    final repo = ref.read(readingPositionRepositoryProvider);
    if (repo == null) return;
    state = AsyncData(
      ReadingPosition(key: key, updatedAt: DateTime.now().toUtc()),
    );
    unawaited(repo.save(key));
  }
}
