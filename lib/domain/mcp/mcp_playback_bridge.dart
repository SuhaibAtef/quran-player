import '../../core/error/result.dart';
import '../../core/error/failure.dart';
import 'mcp_playback_command.dart';

abstract class McpPlaybackBridge {
  bool get isAvailable;

  Future<Result<void>> apply(McpPlaybackCommand command);
}

class UnavailableMcpPlaybackBridge implements McpPlaybackBridge {
  const UnavailableMcpPlaybackBridge();

  @override
  bool get isAvailable => false;

  @override
  Future<Result<void>> apply(McpPlaybackCommand command) async {
    return const Result.err(
      DataAccessFailure('The app player is not available for MCP control.'),
    );
  }
}
