import '../../core/error/failure.dart';
import '../../core/error/result.dart';
import '../quran/ayah_key.dart';
import 'audio_queue_item.dart';

Result<Uri> validatePlayableUri(String input, {Uri? baseUri}) {
  final trimmed = input.trim();
  if (trimmed.isEmpty) {
    return const Result.err(InvalidInputFailure('audio URL is empty'));
  }
  final raw = Uri.tryParse(trimmed);
  if (raw == null) {
    return Result.err(InvalidInputFailure('invalid audio URL: $input'));
  }
  final uri = raw.hasScheme ? raw : baseUri?.resolveUri(raw);
  if (uri == null || uri.scheme != 'https') {
    return Result.err(InvalidInputFailure('unsupported audio URL: $input'));
  }
  return Result.ok(uri);
}

Result<AyahKey> validateSourceVerseKey(String verseKey, {AyahKey? expected}) {
  final parsed = AyahKey.parse(verseKey);
  if (parsed is Err<AyahKey>) return parsed;
  final key = (parsed as Ok<AyahKey>).value;
  if (expected != null && key != expected) {
    return Result.err(
      DataIntegrityFailure(
        'audio verse key mismatch: expected $expected, got $key',
      ),
    );
  }
  return Result.ok(key);
}

Result<List<AudioQueueItem>> validateQueueOrder(
  List<AudioQueueItem> queue,
  List<AyahKey> expectedKeys,
) {
  if (queue.length != expectedKeys.length) {
    return Result.err(
      DataIntegrityFailure(
        'audio queue length mismatch: expected ${expectedKeys.length}, '
        'got ${queue.length}',
      ),
    );
  }
  for (var i = 0; i < expectedKeys.length; i++) {
    final actual = queue[i].track.ayahKey;
    if (actual != expectedKeys[i]) {
      return Result.err(
        DataIntegrityFailure(
          'audio queue order mismatch at $i: expected ${expectedKeys[i]}, '
          'got $actual',
        ),
      );
    }
  }
  return Result.ok(queue);
}
