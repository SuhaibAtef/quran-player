import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../app/state/app_bootstrap_status_provider.dart';
import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/quran_repository.dart';
import 'mcp_dtos.dart';
import 'mcp_error_mapper.dart';

/// Bridges the workspace package's `McpQuranDataPort` to the host's
/// `QuranRepository`. Handles `Failure` → `McpException` conversion at the
/// boundary so the package never sees host-side error types.
class HostQuranDataAdapter implements McpQuranDataPort {
  HostQuranDataAdapter({
    required this.repository,
    required this.bootstrapStatus,
  });

  final QuranRepository repository;
  final AppBootstrapStatus Function() bootstrapStatus;

  @override
  void ensureAvailable() {
    final status = bootstrapStatus();
    switch (status.state) {
      case AppBootstrapState.ok:
        return;
      case AppBootstrapState.loading:
        throw const McpException(
          McpError(
            McpErrorCode.unavailable,
            'App data is still bootstrapping.',
          ),
        );
      case AppBootstrapState.fatal:
        throw McpException(
          mcpErrorFromFailure(
            status.failure ??
                const DataIntegrityFailure('App data integrity failed.'),
          ),
        );
    }
  }

  @override
  Future<List<Map<String, Object?>>> listSurahsJson() async {
    final surahs = _unwrap(await repository.listSurahs());
    return surahs.map(surahToMcpJson).toList(growable: false);
  }

  @override
  Future<Map<String, Object?>> getSurahJson(int surah) async {
    final value = _unwrap(await repository.getSurah(surah));
    return surahToMcpJson(value);
  }

  @override
  Future<List<Map<String, Object?>>> getSurahAyahsJson(int surah) async {
    final ayahs = _unwrap(await repository.getSurahAyahs(surah));
    return ayahs.map(ayahToMcpJson).toList(growable: false);
  }

  @override
  Future<Map<String, Object?>> getAyahJson(int surah, int ayah) async {
    final key = _unwrap(AyahKey.tryNew(surah, ayah));
    final value = _unwrap(await repository.getAyah(key));
    return ayahToMcpJson(value);
  }

  @override
  Future<List<Map<String, Object?>>> searchAyahsJson(
    String query, {
    required int limit,
  }) async {
    final results = _unwrap(await repository.searchAyahs(query, limit: limit));
    return results.map(searchResultToMcpJson).toList(growable: false);
  }

  @override
  Future<Map<String, Object?>> getSourceJson() async {
    final value = _unwrap(await repository.getSource());
    return quranSourceToMcpJson(value);
  }

  T _unwrap<T>(Result<T> result) {
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw McpException(mcpErrorFromFailure(failure)),
    };
  }
}
