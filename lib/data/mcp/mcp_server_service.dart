import 'package:quran_mcp_server/quran_mcp_server.dart';

import '../../core/error/result.dart';
import '../../domain/audio/audio_repository.dart';
import '../../domain/mcp/mcp_playback_bridge.dart';
import '../../domain/mcp/mcp_playback_command.dart';
import '../../domain/quran/ayah_key.dart';
import '../../domain/quran/quran_repository.dart';
import 'mcp_dtos.dart';
import 'mcp_error_mapper.dart';

typedef McpDataAvailable = Result<void> Function();
typedef McpPermissionRequest =
    Future<Result<void>> Function(McpPlaybackCommand command);

class McpToolDefinition {
  const McpToolDefinition({
    required this.name,
    required this.description,
    required this.inputSchema,
  });

  final String name;
  final String description;
  final Map<String, Object?> inputSchema;

  Map<String, Object?> toJson() => {
    'name': name,
    'description': description,
    'inputSchema': inputSchema,
  };
}

class McpResourceDefinition {
  const McpResourceDefinition({required this.uri, required this.name});

  final String uri;
  final String name;

  Map<String, Object?> toJson() => {'uri': uri, 'name': name};
}

class McpServerService {
  McpServerService({
    required QuranRepository quranRepository,
    required AudioRepository audioRepository,
    required McpPlaybackBridge playbackBridge,
    required McpPermissionRequest requestPermission,
    McpDataAvailable? dataAvailable,
  }) : _quranRepository = quranRepository,
       _audioRepository = audioRepository,
       _playbackBridge = playbackBridge,
       _requestPermission = requestPermission,
       _dataAvailable = dataAvailable ?? (() => const Result.ok(null));

  final QuranRepository _quranRepository;
  final AudioRepository _audioRepository;
  final McpPlaybackBridge _playbackBridge;
  final McpPermissionRequest _requestPermission;
  final McpDataAvailable _dataAvailable;

  static const toolNames = [
    'search_quran',
    'get_ayah',
    'get_surah',
    'list_surahs',
    'list_reciters',
    'play_surah',
    'play_ayah',
    'pause_playback',
    'resume_playback',
    'stop_playback',
    'set_repeat',
  ];

  static const resourceUris = [
    'quran://metadata',
    'quran://surahs',
    'quran://surah/{surah}',
    'quran://ayah/{surah}/{ayah}',
    'quran://reciters',
  ];

  List<McpToolDefinition> listTools() {
    return [
      _tool('search_quran', 'Search canonical Quran text', {
        'query': 'string',
        'limit': 'integer optional, 1..50',
      }),
      _tool('get_ayah', 'Get one canonical ayah', {
        'surah': 'integer 1..114',
        'ayah': 'integer >=1',
      }),
      _tool('get_surah', 'Get one surah and all canonical ayahs', {
        'surah': 'integer 1..114',
      }),
      _tool('list_surahs', 'List all Quran surahs', const {}),
      _tool('list_reciters', 'List approved reciters', const {}),
      _tool('play_surah', 'Request user approval to play a surah', {
        'surah': 'integer 1..114',
      }),
      _tool('play_ayah', 'Request user approval to play an ayah', {
        'surah': 'integer 1..114',
        'ayah': 'integer >=1',
      }),
      _tool(
        'pause_playback',
        'Request user approval to pause playback',
        const {},
      ),
      _tool(
        'resume_playback',
        'Request user approval to resume playback',
        const {},
      ),
      _tool(
        'stop_playback',
        'Request user approval to stop playback',
        const {},
      ),
      _tool('set_repeat', 'Request user approval to set repeat mode', {
        'mode': 'off',
      }),
    ];
  }

  List<McpResourceDefinition> listResources() {
    return [
      const McpResourceDefinition(
        uri: 'quran://metadata',
        name: 'Quran metadata',
      ),
      const McpResourceDefinition(uri: 'quran://surahs', name: 'Surahs'),
      const McpResourceDefinition(
        uri: 'quran://surah/{surah}',
        name: 'Single surah',
      ),
      const McpResourceDefinition(
        uri: 'quran://ayah/{surah}/{ayah}',
        name: 'Single ayah',
      ),
      const McpResourceDefinition(uri: 'quran://reciters', name: 'Reciters'),
    ];
  }

  Future<Map<String, Object?>> callTool(
    String name, [
    Map<String, Object?> args = const {},
  ]) async {
    return switch (name) {
      'search_quran' => _searchQuran(args),
      'get_ayah' => _getAyah(args),
      'get_surah' => _getSurah(args),
      'list_surahs' => _listSurahs(),
      'list_reciters' => _listReciters(),
      'play_surah' => _requestPlayback(McpPlaybackCommandType.playSurah, args),
      'play_ayah' => _requestPlayback(McpPlaybackCommandType.playAyah, args),
      'pause_playback' => _requestPlayback(
        McpPlaybackCommandType.pausePlayback,
        args,
      ),
      'resume_playback' => _requestPlayback(
        McpPlaybackCommandType.resumePlayback,
        args,
      ),
      'stop_playback' => _requestPlayback(
        McpPlaybackCommandType.stopPlayback,
        args,
      ),
      'set_repeat' => _requestPlayback(McpPlaybackCommandType.setRepeat, args),
      _ => throw McpException(
        McpError(McpErrorCode.invalidInput, 'Unknown MCP tool: $name'),
      ),
    };
  }

  Future<Map<String, Object?>> readResource(String uri) async {
    _ensureDataAvailable();
    if (uri == 'quran://metadata') {
      final source = await _unwrap(_quranRepository.getSource());
      return {'metadata': quranSourceToMcpJson(source)};
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
      return _getSurah({'surah': int.tryParse(segments[0])});
    }
    if (parts.host == 'ayah' && segments.length == 2) {
      return _getAyah({
        'surah': int.tryParse(segments[0]),
        'ayah': int.tryParse(segments[1]),
      });
    }
    throw McpException(
      McpError(McpErrorCode.invalidInput, 'Unknown MCP resource: $uri'),
    );
  }

  Future<Map<String, Object?>> _listSurahs() async {
    _ensureDataAvailable();
    final surahs = await _unwrap(_quranRepository.listSurahs());
    return {'surahs': surahs.map(surahToMcpJson).toList(growable: false)};
  }

  Future<Map<String, Object?>> _getAyah(Map<String, Object?> args) async {
    _ensureDataAvailable();
    final key = _ayahKeyFromArgs(args);
    final ayah = await _unwrap(_quranRepository.getAyah(key));
    return {'ayah': ayahToMcpJson(ayah)};
  }

  Future<Map<String, Object?>> _getSurah(Map<String, Object?> args) async {
    _ensureDataAvailable();
    final surahNumber = _requiredInt(args, 'surah');
    _validateSurah(surahNumber);
    final surah = await _unwrap(_quranRepository.getSurah(surahNumber));
    final ayahs = await _unwrap(_quranRepository.getSurahAyahs(surahNumber));
    return {
      'surah': surahToMcpJson(surah),
      'ayahs': ayahs.map(ayahToMcpJson).toList(growable: false),
    };
  }

  Future<Map<String, Object?>> _searchQuran(Map<String, Object?> args) async {
    _ensureDataAvailable();
    final query = _requiredString(args, 'query').trim();
    if (query.isEmpty) {
      throw const McpException(
        McpError(McpErrorCode.invalidInput, 'Search query must not be empty.'),
      );
    }
    final limit = args.containsKey('limit') ? _requiredInt(args, 'limit') : 50;
    if (limit < 1 || limit > 50) {
      throw const McpException(
        McpError(McpErrorCode.invalidInput, 'Search limit must be in 1..50.'),
      );
    }
    final results = await _unwrap(
      _quranRepository.searchAyahs(query, limit: limit),
    );
    return {
      'results': results.map(searchResultToMcpJson).toList(growable: false),
    };
  }

  Future<Map<String, Object?>> _listReciters() async {
    final reciter = await _unwrap(_audioRepository.getDefaultReciter());
    return {
      'reciters': [reciterToMcpJson(reciter)],
    };
  }

  Future<Map<String, Object?>> _requestPlayback(
    McpPlaybackCommandType type,
    Map<String, Object?> args,
  ) async {
    if (!_playbackBridge.isAvailable) {
      throw const McpException(
        McpError(McpErrorCode.unavailable, 'The app player is unavailable.'),
      );
    }

    final command = _playbackCommand(type, args);
    final permission = await _requestPermission(command);
    if (permission is Err<void>) {
      throw McpException(
        McpError(McpErrorCode.permissionDenied, permission.failure.message),
      );
    }
    final result = await _playbackBridge.apply(command);
    if (result is Err<void>) {
      throw McpException(
        McpError(McpErrorCode.playerFailure, result.failure.message),
      );
    }
    return {
      'status': 'applied',
      'command': command.type.name,
      'label': command.label,
    };
  }

  McpPlaybackCommand _playbackCommand(
    McpPlaybackCommandType type,
    Map<String, Object?> args,
  ) {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    return switch (type) {
      McpPlaybackCommandType.playSurah => McpPlaybackCommand(
        id: id,
        type: type,
        surah: _validateSurah(_requiredInt(args, 'surah')),
        clientName: _optionalString(args, 'clientName'),
      ),
      McpPlaybackCommandType.playAyah => McpPlaybackCommand(
        id: id,
        type: type,
        ayahKey: _ayahKeyFromArgs(args),
        clientName: _optionalString(args, 'clientName'),
      ),
      McpPlaybackCommandType.setRepeat => McpPlaybackCommand(
        id: id,
        type: type,
        repeatMode: _repeatMode(args),
        clientName: _optionalString(args, 'clientName'),
      ),
      _ => McpPlaybackCommand(
        id: id,
        type: type,
        clientName: _optionalString(args, 'clientName'),
      ),
    };
  }

  McpRepeatMode _repeatMode(Map<String, Object?> args) {
    final mode = _requiredString(args, 'mode').trim();
    if (mode == 'off') return McpRepeatMode.off;
    throw McpException(
      McpError(
        McpErrorCode.invalidInput,
        'Unsupported repeat mode "$mode". Supported mode: off.',
      ),
    );
  }

  AyahKey _ayahKeyFromArgs(Map<String, Object?> args) {
    final surah = _requiredInt(args, 'surah');
    final ayah = _requiredInt(args, 'ayah');
    final result = AyahKey.tryNew(surah, ayah);
    return _unwrapSync(result);
  }

  int _validateSurah(int value) {
    if (value < 1 || value > 114) {
      throw McpException(
        McpError(McpErrorCode.invalidInput, 'Surah must be in 1..114.'),
      );
    }
    return value;
  }

  int _requiredInt(Map<String, Object?> args, String field) {
    final value = args[field];
    if (value is int) return value;
    throw McpException(
      McpError(McpErrorCode.invalidInput, 'Expected integer field "$field".'),
    );
  }

  String _requiredString(Map<String, Object?> args, String field) {
    final value = args[field];
    if (value is String) return value;
    throw McpException(
      McpError(McpErrorCode.invalidInput, 'Expected string field "$field".'),
    );
  }

  String? _optionalString(Map<String, Object?> args, String field) {
    final value = args[field];
    if (value == null) return null;
    if (value is String) return value;
    throw McpException(
      McpError(McpErrorCode.invalidInput, 'Expected string field "$field".'),
    );
  }

  void _ensureDataAvailable() {
    final available = _dataAvailable();
    if (available is Err<void>) {
      throw McpException(mcpErrorFromFailure(available.failure));
    }
  }

  T _unwrapSync<T>(Result<T> result) {
    return switch (result) {
      Ok(:final value) => value,
      Err(:final failure) => throw McpException(mcpErrorFromFailure(failure)),
    };
  }

  Future<T> _unwrap<T>(Future<Result<T>> future) async {
    final result = await future;
    return _unwrapSync(result);
  }
}

McpToolDefinition _tool(
  String name,
  String description,
  Map<String, Object?> inputSchema,
) {
  return McpToolDefinition(
    name: name,
    description: description,
    inputSchema: inputSchema,
  );
}
