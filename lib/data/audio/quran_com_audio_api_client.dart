import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import 'quran_com_audio_source.dart';

class QuranComAudioApiClient {
  QuranComAudioApiClient({
    http.Client? client,
    Uri? apiBaseUri,
    Duration timeout = const Duration(seconds: 15),
  }) : _client = client ?? http.Client(),
       _apiBaseUri = apiBaseUri ?? QuranComAudioSource.apiBaseUri,
       _timeout = timeout;

  final http.Client _client;
  final Uri _apiBaseUri;
  final Duration _timeout;

  Future<Result<Map<String, Object?>>> getRecitations() async {
    return _getJson(_apiBaseUri.resolve('resources/recitations'));
  }

  Future<Result<Map<String, Object?>>> getSurahRecitation({
    required int sourceRecitationId,
    required int chapterNumber,
    required int page,
    int perPage = 50,
  }) {
    final uri = _apiBaseUri
        .resolve('quran/recitations/$sourceRecitationId')
        .replace(
          queryParameters: {
            'chapter_number': '$chapterNumber',
            'page': '$page',
            'per_page': '$perPage',
            'fields': 'verse_key,url,duration,format,id',
          },
        );
    return _getJson(uri);
  }

  Future<Result<Map<String, Object?>>> _getJson(Uri uri) async {
    try {
      final response = await _client.get(uri).timeout(_timeout);
      if (response.statusCode < 200 || response.statusCode >= 300) {
        return Result.err(
          NetworkFailure(
            'audio API request failed (${response.statusCode})',
            statusCode: response.statusCode,
          ),
        );
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, Object?>) {
        return const Result.err(
          DataAccessFailure('audio API returned non-object JSON'),
        );
      }
      return Result.ok(decoded);
    } on http.ClientException catch (e, st) {
      return Result.err(
        NetworkFailure('audio API network error', cause: e, stackTrace: st),
      );
    } on FormatException catch (e, st) {
      return Result.err(
        DataAccessFailure(
          'audio API returned invalid JSON',
          cause: e,
          stackTrace: st,
        ),
      );
    } on Object catch (e, st) {
      return Result.err(
        NetworkFailure('audio API request failed', cause: e, stackTrace: st),
      );
    }
  }
}
