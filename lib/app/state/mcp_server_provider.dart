import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../core/logging/logger.dart';
import '../../data/audio/providers.dart';
import '../../data/mcp/host_audio_adapter.dart';
import '../../data/mcp/host_quran_data_adapter.dart';
import '../../data/quran/providers.dart';
import '../../features/player/state/audio_player_controller.dart';
import 'app_bootstrap_status_provider.dart';
import 'mcp_settings_provider.dart';
import 'user_db_provider.dart';

/// Server lifecycle controller. The Settings master toggle drives start/stop
/// via this controller; the MCP Status page consumes the `McpServerStatus`
/// it exposes for live UI.
class McpServerController extends StateNotifier<McpServerStatus> {
  McpServerController(this._ref) : super(const McpServerStatus.disabled());

  final Ref _ref;
  QuranMcpServer? _server;

  Future<void> start() async {
    if (_server != null || state.lifecycle == McpServerLifecycle.starting) {
      return;
    }
    state = state.copyWith(
      lifecycle: McpServerLifecycle.starting,
      clearMessage: true,
      clearConnection: true,
    );

    try {
      final server = QuranMcpServer(
        quran: HostQuranDataAdapter(
          repository: _ref.read(quranRepositoryProvider),
          bootstrapStatus: () => _ref.read(appBootstrapStatusProvider),
        ),
        audio: HostAudioAdapter(
          audioRepository: _ref.read(audioRepositoryProvider),
          controller: _ref.read(audioPlayerControllerProvider.notifier),
        ),
        scopeCheck: _ref.read(scopeCheckProvider),
        audit: _ref.read(auditLogRepositoryProvider),
      );

      final port = _ref.read(mcpSettingsControllerProvider).port;
      final status = await server.start(port: port);
      _server = server;
      state = status;
      appLogger.info(
        'MCP server started at ${status.uri} (token redacted, length=${status.authToken?.length ?? 0})',
      );
    } on Object catch (e, st) {
      appLogger.warning('MCP server start failed', e, st);
      state = state.copyWith(
        lifecycle: McpServerLifecycle.failed,
        message: 'Failed to start MCP server: $e',
        clearConnection: true,
      );
    }
  }

  Future<void> stop() async {
    final s = _server;
    _server = null;
    await s?.stop();
    state = state.copyWith(
      lifecycle: McpServerLifecycle.stopped,
      clearMessage: true,
      clearConnection: true,
    );
  }

  @override
  void dispose() {
    final s = _server;
    _server = null;
    s?.stop();
    super.dispose();
  }
}

final mcpServerControllerProvider =
    StateNotifierProvider<McpServerController, McpServerStatus>((ref) {
      return McpServerController(ref);
    });

/// Streams the most-recent N audit log rows for the MCP Status page. Returns
/// an empty list when `user.db` is unavailable.
final mcpRecentAuditProvider = FutureProvider.autoDispose<List<AuditEntry>>((
  ref,
) async {
  final repo = ref.watch(auditLogRepositoryProvider);
  if (repo == null) return const [];
  return repo.recent(20);
});
