/// Host-supplied ports the MCP server depends on.
///
/// The package defines these abstract interfaces so it can stay isolated from
/// `package:quran_player/`. The host app provides adapters that wrap its
/// `QuranRepository`, `AudioRepository`, and `AudioPlayerController` and
/// surface the JSON shapes the tool handlers serialize back over MCP.
///
/// Adapters MUST throw [McpException] on failure (after mapping host-side
/// `Failure` types). The dispatcher in the package catches it and turns it
/// into the protocol-level error response. They MUST NOT leak host-side
/// exception types across the package boundary.
library;

import 'mcp_error.dart';

/// Read-only Quran corpus access. Returns JSON-shaped maps that the tool
/// handlers can pass through to the MCP response unchanged.
abstract class McpQuranDataPort {
  /// Sentinel that returns `Result<void>` semantics encoded as either
  /// returning normally (data available) or throwing [McpException]
  /// (data unavailable — e.g., bundled Quran integrity check failed).
  void ensureAvailable();

  Future<List<Map<String, Object?>>> listSurahsJson();
  Future<Map<String, Object?>> getSurahJson(int surah);
  Future<List<Map<String, Object?>>> getSurahAyahsJson(int surah);
  Future<Map<String, Object?>> getAyahJson(int surah, int ayah);
  Future<List<Map<String, Object?>>> searchAyahsJson(
    String query, {
    required int limit,
  });
  Future<Map<String, Object?>> getSourceJson();
}

/// Audio reciter listing + playback control. Mode B tools call into this
/// only after their scope check passes.
abstract class McpAudioPort {
  /// `false` when the host audio engine failed to initialize. Mode B tools
  /// turn this into `McpErrorCode.unavailable`.
  bool get isAvailable;

  Future<Map<String, Object?>> getDefaultReciterJson();

  Future<void> playSurah(int surah);
  Future<void> playAyah(int surah, int ayah);
  Future<void> pausePlayback();
  Future<void> resumePlayback();
  Future<void> stopPlayback();

  /// `mode` is the protocol-level string (e.g. `"off"`). The host adapter
  /// validates and maps to the host's domain enum. Throws [McpException]
  /// with `McpErrorCode.invalidInput` for unsupported modes.
  Future<void> setRepeat(String mode);
}
