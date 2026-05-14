import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/state/theme_mode_provider.dart'
    show sharedPreferencesProvider;
import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../core/logging/logger.dart';
import '../../domain/tafsir/tafsir_repository.dart';
import '../quran/providers.dart';
import 'integrity_checker.dart';
import 'manifest.dart';
import 'tafsir_database.dart';
import 'tafsir_repository_sqlite.dart';

/// Bundle of everything the app needs once the tafsir data layer is initialised
/// and verified.
class TafsirBootstrap {
  const TafsirBootstrap({
    required this.repository,
    required this.manifest,
    required this.report,
  });

  final TafsirRepository repository;
  final TafsirManifest manifest;
  final TafsirIntegrityReport report;
}

/// Initialises the tafsir data layer end-to-end. Runs once per launch.
///
/// Depends on `quranBootstrapProvider` because the integrity check
/// cross-references every tafsir (surah, ayah) against the bundled Quran DB.
/// If the Quran bootstrap is still loading or failed, this provider yields the
/// same failure so the composite gate stays coherent.
final tafsirBootstrapProvider = FutureProvider<Result<TafsirBootstrap>>((
  ref,
) async {
  // Wait for Quran bootstrap; surface its failure if it tripped.
  final quranAsync = ref.watch(quranBootstrapProvider);
  final quranResult = await quranAsync.when(
    data: (r) async => r,
    loading: () async {
      final future = ref.read(quranBootstrapProvider.future);
      return future;
    },
    error: (e, st) async => Result<QuranBootstrap>.err(
      e is Failure ? e : DataAccessFailure('quran bootstrap error: $e'),
    ),
  );
  if (quranResult is Err<QuranBootstrap>) {
    return Result.err(quranResult.failure);
  }
  final quran = (quranResult as Ok<QuranBootstrap>).value;
  final quranDatabase = quran.database;
  if (quranDatabase == null) {
    return Result.err(
      DataAccessFailure(
        'Quran bootstrap did not expose a database handle; '
        'tafsirBootstrapProvider must be overridden in tests that use a '
        'fake Quran bootstrap.',
      ),
    );
  }

  appLogger.info('Tafsir bootstrap: loading manifest');
  final manifestResult = await loadTafsirManifestFromBundle(rootBundle);
  if (manifestResult is Err<TafsirManifest>) {
    appLogger.severe(
      'Tafsir bootstrap: manifest load failed: ${manifestResult.failure}',
    );
    return Result.err(manifestResult.failure);
  }
  final manifest = (manifestResult as Ok<TafsirManifest>).value;

  appLogger.info('Tafsir bootstrap: opening database');
  final dbResult = await TafsirDatabaseFactory().open(rootBundle);
  if (dbResult is Err<TafsirDatabase>) {
    appLogger.severe('Tafsir bootstrap: db open failed: ${dbResult.failure}');
    return Result.err(dbResult.failure);
  }
  final database = (dbResult as Ok<TafsirDatabase>).value;

  ref.onDispose(() {
    appLogger.fine('Tafsir bootstrap: closing database');
    database.close();
  });

  final prefs = ref.read(sharedPreferencesProvider);
  appLogger.info('Tafsir bootstrap: verifying integrity');
  final integrityResult = await verifyTafsirIntegrity(
    tafsirDatabase: database,
    quranDatabase: quranDatabase,
    manifest: manifest,
    prefs: prefs,
  );
  if (integrityResult is Err<TafsirIntegrityReport>) {
    appLogger.severe(
      'Tafsir bootstrap: integrity check failed: ${integrityResult.failure}',
    );
    return Result.err(integrityResult.failure);
  }
  final report = (integrityResult as Ok<TafsirIntegrityReport>).value;
  appLogger.info(
    'Tafsir bootstrap: integrity OK (skippedHash=${report.skippedHash})',
  );

  final repository = TafsirRepositorySqlite(
    database: database,
    manifest: manifest,
  );
  return Result.ok(
    TafsirBootstrap(repository: repository, manifest: manifest, report: report),
  );
});

/// Synchronous handle to the tafsir repository. Throws if bootstrap has not
/// completed successfully — mirrors `quranRepositoryProvider`.
final tafsirRepositoryProvider = Provider<TafsirRepository>((ref) {
  final async = ref.watch(tafsirBootstrapProvider);
  return async.when(
    data: (result) => switch (result) {
      Ok(:final value) => value.repository,
      Err(:final failure) => throw _BootstrapNotReady(failure),
    },
    error: (e, st) => throw StateError('Tafsir bootstrap errored: $e'),
    loading: () =>
        throw StateError('Tafsir bootstrap still loading; await it first'),
  );
});

class _BootstrapNotReady extends StateError {
  _BootstrapNotReady(Failure failure)
    : super('Tafsir bootstrap not ready: $failure');
}
