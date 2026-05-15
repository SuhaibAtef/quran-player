import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_mcp_server/quran_mcp_server.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'theme_mode_provider.dart' show sharedPreferencesProvider;

/// SharedPreferences keys for the MCP Settings surface (single source of
/// truth for the names — UI widgets, the scope check, and the server lifecycle
/// all read these constants).
class McpPrefs {
  const McpPrefs._();

  /// Master toggle. When OFF the server doesn't start and no scope is queried.
  /// When ON, [Scope.readonly] is implicit; the two Mode B scopes below are
  /// independent. Default OFF — first-run safety, user opts in.
  static const enabled = 'mcp.enabled';

  /// Mode B playback scope. Default OFF.
  static const scopePlayback = 'mcp.scope.playback';

  /// Mode B bookmark scope. Default OFF, reserved (no tools gate on it yet).
  static const scopeBookmark = 'mcp.scope.bookmark';

  /// User-configurable port. `0` means "ask the OS" on next start.
  static const port = 'mcp.port';
}

/// Snapshot of every MCP-related Settings flag. Watched by Settings UI and
/// the MCP Status page; rebuilt whenever any toggle changes via
/// [McpSettingsController].
class McpSettings {
  const McpSettings({
    required this.enabled,
    required this.scopePlayback,
    required this.scopeBookmark,
    required this.port,
  });

  final bool enabled;
  final bool scopePlayback;
  final bool scopeBookmark;
  final int port;
}

class McpSettingsController extends StateNotifier<McpSettings> {
  McpSettingsController(this._prefs)
    : super(
        McpSettings(
          enabled: _prefs.getBool(McpPrefs.enabled) ?? false,
          scopePlayback: _prefs.getBool(McpPrefs.scopePlayback) ?? false,
          scopeBookmark: _prefs.getBool(McpPrefs.scopeBookmark) ?? false,
          port: _prefs.getInt(McpPrefs.port) ?? 0,
        ),
      );

  final SharedPreferences _prefs;

  Future<void> setEnabled(bool value) async {
    await _prefs.setBool(McpPrefs.enabled, value);
    state = McpSettings(
      enabled: value,
      scopePlayback: state.scopePlayback,
      scopeBookmark: state.scopeBookmark,
      port: state.port,
    );
  }

  Future<void> setScopePlayback(bool value) async {
    await _prefs.setBool(McpPrefs.scopePlayback, value);
    state = McpSettings(
      enabled: state.enabled,
      scopePlayback: value,
      scopeBookmark: state.scopeBookmark,
      port: state.port,
    );
  }

  Future<void> setScopeBookmark(bool value) async {
    await _prefs.setBool(McpPrefs.scopeBookmark, value);
    state = McpSettings(
      enabled: state.enabled,
      scopePlayback: state.scopePlayback,
      scopeBookmark: value,
      port: state.port,
    );
  }

  Future<void> setPort(int value) async {
    await _prefs.setInt(McpPrefs.port, value);
    state = McpSettings(
      enabled: state.enabled,
      scopePlayback: state.scopePlayback,
      scopeBookmark: state.scopeBookmark,
      port: value,
    );
  }
}

final mcpSettingsControllerProvider =
    StateNotifierProvider<McpSettingsController, McpSettings>((ref) {
      return McpSettingsController(ref.watch(sharedPreferencesProvider));
    });

/// Live `ScopeCheck` closure. Re-built whenever any toggle changes so the
/// next MCP call sees the updated state without restarting the server.
///
/// Spec mcp-server: `Scope.readonly` is implicit when the master `mcp.enabled`
/// toggle is ON; `Scope.playback` and `Scope.bookmark` are independent and
/// default OFF.
final scopeCheckProvider = Provider<ScopeCheck>((ref) {
  final s = ref.watch(mcpSettingsControllerProvider);
  return (scope) {
    if (!s.enabled) return false;
    return switch (scope) {
      Scope.readonly => true,
      Scope.playback => s.scopePlayback,
      Scope.bookmark => s.scopeBookmark,
    };
  };
});
