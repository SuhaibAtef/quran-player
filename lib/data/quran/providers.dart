import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state/theme_mode_provider.dart'
    show sharedPreferencesProvider;
import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/logger.dart';
import '../../domain/quran/quran_repository.dart';
import 'integrity_checker.dart';
import 'manifest.dart';
import 'quran_database.dart';
import 'quran_repository_sqlite.dart';

/// Bundle of everything the app needs once the Quran data layer is initialised
/// and verified. Treat this as the single source of truth for the Quran.
class QuranBootstrap {
  const QuranBootstrap({
    required this.repository,
    required this.manifest,
    required this.report,
    this.database,
  });

  final QuranRepository repository;
  final QuranManifest manifest;
  final IntegrityReport report;

  /// The opened SQLite handle, exposed so the tafsir integrity check can
  /// cross-reference ayah keys without re-opening the DB. Populated by the
  /// real `quranBootstrapProvider` in production; may be null in widget-test
  /// fakes that don't exercise the tafsir bootstrap.
  final QuranDatabase? database;
}

/// Initialises the Quran data layer end-to-end. Runs once per launch.
final quranBootstrapProvider = FutureProvider<Result<QuranBootstrap>>((
  ref,
) async {
  appLogger.info('Quran bootstrap: loading manifest');
  final manifestResult = await loadManifestFromBundle(rootBundle);
  if (manifestResult is Err<QuranManifest>) {
    appLogger.severe(
      'Quran bootstrap: manifest load failed: ${manifestResult.failure}',
    );
    return Result.err(manifestResult.failure);
  }
  final manifest = (manifestResult as Ok<QuranManifest>).value;

  appLogger.info('Quran bootstrap: opening database');
  final dbResult = await QuranDatabaseFactory().open(rootBundle);
  if (dbResult is Err<QuranDatabase>) {
    appLogger.severe('Quran bootstrap: db open failed: ${dbResult.failure}');
    return Result.err(dbResult.failure);
  }
  final database = (dbResult as Ok<QuranDatabase>).value;

  ref.onDispose(() {
    appLogger.fine('Quran bootstrap: closing database');
    database.close();
  });

  final prefs = ref.read(sharedPreferencesProvider);
  appLogger.info('Quran bootstrap: verifying integrity');
  final integrityResult = await verifyQuranIntegrity(
    database: database,
    manifest: manifest,
    prefs: prefs,
  );
  if (integrityResult is Err<IntegrityReport>) {
    appLogger.severe(
      'Quran bootstrap: integrity check failed: ${integrityResult.failure}',
    );
    return Result.err(integrityResult.failure);
  }
  final report = (integrityResult as Ok<IntegrityReport>).value;
  appLogger.info(
    'Quran bootstrap: integrity OK (skippedHash=${report.skippedHash})',
  );

  final repository = QuranRepositorySqlite(
    database: database,
    manifest: manifest,
  );
  return Result.ok(
    QuranBootstrap(
      repository: repository,
      database: database,
      manifest: manifest,
      report: report,
    ),
  );
});

/// Synchronous handle to the repository. Reads `quranBootstrapProvider`'s
/// value; throws if it has not completed successfully.
final quranRepositoryProvider = Provider<QuranRepository>((ref) {
  final async = ref.watch(quranBootstrapProvider);
  return async.when(
    data: (result) => switch (result) {
      Ok(:final value) => value.repository,
      Err(:final failure) => throw _BootstrapNotReady(failure),
    },
    error: (e, st) => throw StateError('Quran bootstrap errored: $e'),
    loading: () =>
        throw StateError('Quran bootstrap still loading; await it first'),
  );
});

/// Mirror of the bootstrap status, exposed as a Result so feature widgets can
/// fold instead of using AsyncValue + Result double-wrapping.
final quranBootstrapStatusProvider =
    Provider<AsyncValue<Result<QuranBootstrap>>>(
      (ref) => ref.watch(quranBootstrapProvider),
    );

class _BootstrapNotReady extends StateError {
  _BootstrapNotReady(Failure failure)
    : super('Quran bootstrap not ready: $failure');
}
