import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/logger.dart';

/// Resolves the absolute path that the user-writable `user.db` lives at.
///
/// Default implementation places the file at
/// `path_provider.getApplicationSupportDirectory()/quran/user.db` and creates
/// the parent directory if missing. Tests override this provider to redirect
/// at a temp dir or to throw, exercising the graceful-degrade path.
final userDbPathProvider = FutureProvider<String>((ref) async {
  final support = await getApplicationSupportDirectory();
  final dbPath = p.join(support.path, 'quran', 'user.db');
  await Directory(p.dirname(dbPath)).create(recursive: true);
  return dbPath;
});

/// Sealed-ish wrapper around the user-DB lifecycle. Distinct from a generic
/// `AsyncValue` because the failure case is non-fatal — the rest of the app
/// keeps running and the Settings page surfaces a notice.
class UserDbState {
  const UserDbState._({required this.health, this.repository, this.failure});

  factory UserDbState.ready(AuditLogRepository repository) =>
      UserDbState._(health: UserDbHealth.ready, repository: repository);

  factory UserDbState.failed(Failure failure) =>
      UserDbState._(health: UserDbHealth.failed, failure: failure);

  static const loading = UserDbState._(health: UserDbHealth.loading);

  final UserDbHealth health;
  final AuditLogRepository? repository;
  final Failure? failure;
}

enum UserDbHealth { loading, ready, failed }

/// Opens `user.db`, runs the 7-day prune once, and exposes the repository.
///
/// Failures are caught and surfaced as `UserDbState.failed(...)` rather than
/// throwing — per spec mcp-server R5, a corrupt or inaccessible `user.db`
/// MUST NOT block app start. Quran reads and audio playback are unaffected.
final userDbStateProvider = FutureProvider<UserDbState>((ref) async {
  try {
    final path = await ref.watch(userDbPathProvider.future);
    final db = await openUserDb(absolutePath: path);
    ref.onDispose(() async {
      await db.close();
    });
    final repo = AuditLogRepository(db);
    final pruned = await repo.prune7Days();
    appLogger.info('user.db audit_log prune complete (count=$pruned)');
    return UserDbState.ready(repo);
  } on Object catch (error, stackTrace) {
    appLogger.severe('user.db open failed', error, stackTrace);
    return UserDbState.failed(DataAccessFailure('user.db unavailable: $error'));
  }
});

/// Health-only projection for the Settings page to render the non-fatal
/// notice without unwrapping the full state.
final userDbHealthProvider = Provider<AsyncValue<UserDbHealth>>((ref) {
  return ref.watch(
    userDbStateProvider.select((async) => async.whenData((s) => s.health)),
  );
});

/// Repository for callers that want to append audit rows. Returns `null` when
/// `user.db` failed to open — callers MUST NOT crash; they log a warning and
/// proceed without auditing per R5.
final auditLogRepositoryProvider = Provider<AuditLogRepository?>((ref) {
  final async = ref.watch(userDbStateProvider);
  return async.whenOrNull(data: (state) => state.repository);
});

/// Convenience for tests that want to wait for the open + prune to complete.
Future<Result<UserDbHealth>> awaitUserDbReady(
  Ref ref, {
  Duration timeout = const Duration(seconds: 5),
}) async {
  final state = await ref.read(userDbStateProvider.future).timeout(timeout);
  return Result.ok(state.health);
}
