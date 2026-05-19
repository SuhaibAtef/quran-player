import 'package:quran_mcp_server/quran_mcp_server.dart';

/// Tracks every method call made against [McpQuranDataPort] so tests can
/// assert which side effects fired and which didn't.
class RecordingQuranPort implements McpQuranDataPort {
  RecordingQuranPort({this.available = true});

  bool available;
  final calls = <String>[];

  @override
  void ensureAvailable() {
    calls.add('ensureAvailable');
    if (!available) {
      throw const McpException(
        McpError(McpErrorCode.unavailable, 'fake quran unavailable'),
      );
    }
  }

  @override
  Future<List<Map<String, Object?>>> listSurahsJson() async {
    calls.add('listSurahsJson');
    return [];
  }

  @override
  Future<Map<String, Object?>> getAyahJson(int surah, int ayah) async {
    calls.add('getAyahJson($surah,$ayah)');
    return {'surah': surah, 'ayah': ayah, 'text': 'fake'};
  }

  @override
  Future<Map<String, Object?>> getSurahJson(int surah) async {
    calls.add('getSurahJson($surah)');
    return {'number': surah};
  }

  @override
  Future<List<Map<String, Object?>>> getSurahAyahsJson(int surah) async {
    calls.add('getSurahAyahsJson($surah)');
    return [];
  }

  @override
  Future<List<Map<String, Object?>>> searchAyahsJson(
    String query, {
    required int limit,
  }) async {
    calls.add('searchAyahsJson($query,$limit)');
    return [];
  }

  @override
  Future<Map<String, Object?>> getSourceJson() async {
    calls.add('getSourceJson');
    return {'name': 'fake'};
  }
}

class RecordingAudioPort implements McpAudioPort {
  RecordingAudioPort({this.available = true});

  bool available;
  final calls = <String>[];

  @override
  bool get isAvailable => available;

  @override
  Future<Map<String, Object?>> getDefaultReciterJson() async {
    calls.add('getDefaultReciterJson');
    return {'id': 'fake'};
  }

  @override
  Future<void> playSurah(int surah) async {
    calls.add('playSurah($surah)');
  }

  @override
  Future<void> playAyah(int surah, int ayah) async {
    calls.add('playAyah($surah,$ayah)');
  }

  @override
  Future<void> pausePlayback() async {
    calls.add('pausePlayback');
  }

  @override
  Future<void> resumePlayback() async {
    calls.add('resumePlayback');
  }

  @override
  Future<void> stopPlayback() async {
    calls.add('stopPlayback');
  }

  @override
  Future<void> setRepeat(String mode) async {
    calls.add('setRepeat($mode)');
  }
}
