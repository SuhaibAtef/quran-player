import '../audit/args_summary.dart';
import '../mcp_error.dart';
import '../ports.dart';
import '../scopes/scope.dart';
import 'tool_arg_helpers.dart';
import 'tool_definition.dart';

/// Static set of tool definitions exposed to MCP clients via `list_tools`.
const mcpToolDefinitions = <McpToolDefinition>[
  McpToolDefinition(
    name: 'search_quran',
    description: 'Search canonical Quran text',
    inputSchema: {'query': 'string', 'limit': 'integer optional, 1..50'},
  ),
  McpToolDefinition(
    name: 'get_ayah',
    description: 'Get one canonical ayah',
    inputSchema: {'surah': 'integer 1..114', 'ayah': 'integer >=1'},
  ),
  McpToolDefinition(
    name: 'get_surah',
    description: 'Get one surah and all canonical ayahs',
    inputSchema: {'surah': 'integer 1..114'},
  ),
  McpToolDefinition(
    name: 'list_surahs',
    description: 'List all Quran surahs',
    inputSchema: {},
  ),
  McpToolDefinition(
    name: 'list_reciters',
    description: 'List approved reciters',
    inputSchema: {},
  ),
  McpToolDefinition(
    name: 'play_surah',
    description: 'Play a surah (requires playback scope)',
    inputSchema: {'surah': 'integer 1..114'},
  ),
  McpToolDefinition(
    name: 'play_ayah',
    description: 'Play one ayah (requires playback scope)',
    inputSchema: {'surah': 'integer 1..114', 'ayah': 'integer >=1'},
  ),
  McpToolDefinition(
    name: 'pause_playback',
    description: 'Pause playback (requires playback scope)',
    inputSchema: {},
  ),
  McpToolDefinition(
    name: 'resume_playback',
    description: 'Resume playback (requires playback scope)',
    inputSchema: {},
  ),
  McpToolDefinition(
    name: 'stop_playback',
    description: 'Stop playback (requires playback scope)',
    inputSchema: {},
  ),
  McpToolDefinition(
    name: 'set_repeat',
    description: 'Set repeat mode (requires playback scope)',
    inputSchema: {'mode': 'off'},
  ),
];

const mcpResourceDefinitions = <McpResourceDefinition>[
  McpResourceDefinition(uri: 'quran://metadata', name: 'Quran metadata'),
  McpResourceDefinition(uri: 'quran://surahs', name: 'Surahs'),
  McpResourceDefinition(uri: 'quran://surah/{surah}', name: 'Single surah'),
  McpResourceDefinition(
    uri: 'quran://ayah/{surah}/{ayah}',
    name: 'Single ayah',
  ),
  McpResourceDefinition(uri: 'quran://reciters', name: 'Reciters'),
];

/// Names of tools gated by [Scope.playback].
const modeBToolNames = <String>{
  'play_surah',
  'play_ayah',
  'pause_playback',
  'resume_playback',
  'stop_playback',
  'set_repeat',
};

/// Pure tool dispatch — no scope check, no audit log. The caller (the
/// dispatcher / adapter) wraps each call with those concerns.
class ToolHandlers {
  ToolHandlers({required this.quran, required this.audio});

  final McpQuranDataPort quran;
  final McpAudioPort audio;

  Future<Map<String, Object?>> call(
    String name,
    Map<String, Object?> args,
  ) async {
    return switch (name) {
      'search_quran' => _searchQuran(args),
      'get_ayah' => _getAyah(args),
      'get_surah' => _getSurah(args),
      'list_surahs' => _listSurahs(),
      'list_reciters' => _listReciters(),
      'play_surah' => _playSurah(args),
      'play_ayah' => _playAyah(args),
      'pause_playback' => _pause(),
      'resume_playback' => _resume(),
      'stop_playback' => _stop(),
      'set_repeat' => _setRepeat(args),
      _ => throw McpException(
        McpError(McpErrorCode.invalidInput, 'Unknown MCP tool: $name'),
      ),
    };
  }

  Future<Map<String, Object?>> readResource(String uri) async {
    quran.ensureAvailable();
    if (uri == 'quran://metadata') {
      return {'metadata': await quran.getSourceJson()};
    }
    if (uri == 'quran://surahs') return _listSurahs();
    if (uri == 'quran://reciters') return _listReciters();

    final parts = Uri.parse(uri);
    if (parts.scheme != 'quran') {
      throw const McpException(
        McpError(McpErrorCode.invalidInput, 'Unsupported resource scheme'),
      );
    }
    final segments = parts.pathSegments;
    if (parts.host == 'surah' && segments.length == 1) {
      final n = int.tryParse(segments[0]);
      if (n == null) {
        throw const McpException(
          McpError(McpErrorCode.invalidInput, 'Invalid surah segment.'),
        );
      }
      return _getSurah({'surah': n});
    }
    if (parts.host == 'ayah' && segments.length == 2) {
      final s = int.tryParse(segments[0]);
      final a = int.tryParse(segments[1]);
      if (s == null || a == null) {
        throw const McpException(
          McpError(McpErrorCode.invalidInput, 'Invalid ayah segments.'),
        );
      }
      return _getAyah({'surah': s, 'ayah': a});
    }
    throw McpException(
      McpError(McpErrorCode.invalidInput, 'Unknown MCP resource: $uri'),
    );
  }

  Future<Map<String, Object?>> _listSurahs() async {
    quran.ensureAvailable();
    final surahs = await quran.listSurahsJson();
    return {'surahs': surahs};
  }

  Future<Map<String, Object?>> _getAyah(Map<String, Object?> args) async {
    quran.ensureAvailable();
    final key = requireAyahKeyArgs(args);
    final ayah = await quran.getAyahJson(key.surah, key.ayah);
    return {'ayah': ayah};
  }

  Future<Map<String, Object?>> _getSurah(Map<String, Object?> args) async {
    quran.ensureAvailable();
    final n = validateSurahNumber(requiredInt(args, 'surah'));
    final surah = await quran.getSurahJson(n);
    final ayahs = await quran.getSurahAyahsJson(n);
    return {'surah': surah, 'ayahs': ayahs};
  }

  Future<Map<String, Object?>> _searchQuran(Map<String, Object?> args) async {
    quran.ensureAvailable();
    final query = requiredString(args, 'query').trim();
    if (query.isEmpty) {
      throw const McpException(
        McpError(McpErrorCode.invalidInput, 'Search query must not be empty.'),
      );
    }
    final limit = args.containsKey('limit') ? requiredInt(args, 'limit') : 50;
    if (limit < 1 || limit > 50) {
      throw const McpException(
        McpError(McpErrorCode.invalidInput, 'Search limit must be in 1..50.'),
      );
    }
    final results = await quran.searchAyahsJson(query, limit: limit);
    return {'results': results};
  }

  Future<Map<String, Object?>> _listReciters() async {
    final reciter = await audio.getDefaultReciterJson();
    return {
      'reciters': [reciter],
    };
  }

  Future<Map<String, Object?>> _playSurah(Map<String, Object?> args) async {
    _ensurePlayerAvailable();
    final n = validateSurahNumber(requiredInt(args, 'surah'));
    await audio.playSurah(n);
    return {'status': 'applied', 'command': 'play_surah'};
  }

  Future<Map<String, Object?>> _playAyah(Map<String, Object?> args) async {
    _ensurePlayerAvailable();
    final key = requireAyahKeyArgs(args);
    await audio.playAyah(key.surah, key.ayah);
    return {'status': 'applied', 'command': 'play_ayah'};
  }

  Future<Map<String, Object?>> _pause() async {
    _ensurePlayerAvailable();
    await audio.pausePlayback();
    return {'status': 'applied', 'command': 'pause_playback'};
  }

  Future<Map<String, Object?>> _resume() async {
    _ensurePlayerAvailable();
    await audio.resumePlayback();
    return {'status': 'applied', 'command': 'resume_playback'};
  }

  Future<Map<String, Object?>> _stop() async {
    _ensurePlayerAvailable();
    await audio.stopPlayback();
    return {'status': 'applied', 'command': 'stop_playback'};
  }

  Future<Map<String, Object?>> _setRepeat(Map<String, Object?> args) async {
    _ensurePlayerAvailable();
    final mode = requiredString(args, 'mode').trim();
    await audio.setRepeat(mode);
    return {'status': 'applied', 'command': 'set_repeat', 'mode': mode};
  }

  void _ensurePlayerAvailable() {
    if (!audio.isAvailable) {
      throw const McpException(
        McpError(McpErrorCode.unavailable, 'The app player is unavailable.'),
      );
    }
  }
}

/// Renders a per-tool `args_summary` for the audit log.
///
/// `search_quran` queries are passed through [truncateForArgsSummary] (R7).
/// All other tools render a short `key=value` list.
String renderArgsSummary(String toolName, Map<String, Object?> args) {
  if (toolName == 'search_quran') {
    final raw = args['query'];
    if (raw is! String) return '';
    return 'query=${truncateForArgsSummary(raw)}';
  }
  if (args.isEmpty) return '';
  final parts = <String>[];
  args.forEach((k, v) => parts.add('$k=$v'));
  return parts.join(',');
}
