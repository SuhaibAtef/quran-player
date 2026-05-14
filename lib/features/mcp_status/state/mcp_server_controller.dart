import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/state/app_bootstrap_status_provider.dart';
import '../../../core/error/failure.dart';
import '../../../core/error/result.dart';
import '../../../data/audio/providers.dart';
import '../../../data/mcp/mcp_server_service.dart';
import '../../../data/quran/providers.dart';
import '../../../domain/mcp/mcp_lifecycle.dart';
import '../../../domain/mcp/mcp_playback_bridge.dart';
import '../../../domain/mcp/mcp_playback_command.dart';
import '../../player/state/audio_player_controller.dart';
import 'mcp_playback_bridge.dart';

class McpStatusState {
  const McpStatusState({
    required this.server,
    required this.permissions,
    Completer<Result<void>>? pendingCompleter,
  }) : _pendingCompleter = pendingCompleter;

  const McpStatusState.initial()
    : server = const McpServerStatus.disabled(),
      permissions = const McpPlaybackPermissionState(),
      _pendingCompleter = null;

  final McpServerStatus server;
  final McpPlaybackPermissionState permissions;
  final Completer<Result<void>>? _pendingCompleter;

  bool get hasPendingDecision => _pendingCompleter != null;

  McpStatusState copyWith({
    McpServerStatus? server,
    McpPlaybackPermissionState? permissions,
    Completer<Result<void>>? pendingCompleter,
    bool clearPendingCompleter = false,
  }) {
    return McpStatusState(
      server: server ?? this.server,
      permissions: permissions ?? this.permissions,
      pendingCompleter: clearPendingCompleter
          ? null
          : pendingCompleter ?? _pendingCompleter,
    );
  }
}

final mcpStatusControllerProvider =
    StateNotifierProvider<McpStatusController, McpStatusState>((ref) {
      return McpStatusController();
    });

final mcpPlaybackBridgeProvider = Provider<McpPlaybackBridge>((ref) {
  final controller = ref.read(audioPlayerControllerProvider.notifier);
  return AppMcpPlaybackBridge(controller);
});

final mcpServerServiceProvider = Provider<McpServerService>((ref) {
  return McpServerService(
    quranRepository: ref.watch(quranRepositoryProvider),
    audioRepository: ref.watch(audioRepositoryProvider),
    playbackBridge: ref.watch(mcpPlaybackBridgeProvider),
    requestPermission: ref.read(mcpStatusControllerProvider.notifier).request,
    dataAvailable: () {
      final status = ref.read(appBootstrapStatusProvider);
      return switch (status.state) {
        AppBootstrapState.ok => const Result.ok(null),
        AppBootstrapState.loading => const Result.err(
          DataAccessFailure('App data is still bootstrapping.'),
        ),
        AppBootstrapState.fatal => Result.err(
          status.failure ??
              const DataIntegrityFailure('App data integrity failed.'),
        ),
      };
    },
  );
});

class McpStatusController extends StateNotifier<McpStatusState> {
  McpStatusController() : super(const McpStatusState.initial());

  Future<void> start() async {
    state = state.copyWith(
      server: state.server.copyWith(
        lifecycle: McpServerLifecycle.starting,
        clearMessage: true,
      ),
    );
    state = state.copyWith(
      server: state.server.copyWith(lifecycle: McpServerLifecycle.running),
    );
  }

  void stop() {
    state = state.copyWith(
      server: state.server.copyWith(lifecycle: McpServerLifecycle.stopped),
    );
  }

  void fail(String message) {
    state = state.copyWith(
      server: state.server.copyWith(
        lifecycle: McpServerLifecycle.failed,
        message: message,
      ),
    );
  }

  Future<Result<void>> request(McpPlaybackCommand command) {
    if (state.permissions.pending != null || state._pendingCompleter != null) {
      return Future.value(
        const Result.err(
          DataAccessFailure('Another MCP playback command is pending.'),
        ),
      );
    }
    final completer = Completer<Result<void>>();
    state = state.copyWith(
      permissions: state.permissions.copyWith(pending: command),
      pendingCompleter: completer,
    );
    return completer.future.timeout(
      const Duration(seconds: 30),
      onTimeout: () {
        _complete(
          McpPlaybackDecision.timedOut,
          'Permission request timed out.',
        );
        return const Result.err(
          DataAccessFailure('MCP playback permission timed out.'),
        );
      },
    );
  }

  void approvePending() {
    _complete(McpPlaybackDecision.approved, 'Approved');
  }

  void denyPending() {
    _complete(McpPlaybackDecision.denied, 'Denied');
  }

  void _complete(McpPlaybackDecision decision, String message) {
    final command = state.permissions.pending;
    final completer = state._pendingCompleter;
    if (command == null || completer == null || completer.isCompleted) return;

    final record = McpPlaybackDecisionRecord(
      command: command,
      decision: decision,
      decidedAt: DateTime.now(),
      message: message,
    );
    final recent = [record, ...state.permissions.recent].take(5).toList();
    state = state.copyWith(
      permissions: state.permissions.copyWith(
        clearPending: true,
        recent: recent,
      ),
      clearPendingCompleter: true,
    );

    if (decision == McpPlaybackDecision.approved) {
      completer.complete(const Result.ok(null));
    } else {
      completer.complete(
        Result.err(DataAccessFailure('MCP playback command $message')),
      );
    }
  }
}
