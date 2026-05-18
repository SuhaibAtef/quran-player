import '../../core/error/result.dart';
import '../quran/ayah_key.dart';
import 'reading_position.dart';

/// Persistence contract for the last-read reading position, backed by the
/// single-row `reading_position` table in the user-writable `user.db`.
abstract class ReadingPositionRepository {
  /// The recorded reading position, or `Ok(null)` when none has been recorded.
  Future<Result<ReadingPosition?>> load();

  /// Records [key] as the most recent reading position, replacing any prior
  /// one, and returns the saved [ReadingPosition].
  Future<Result<ReadingPosition>> save(AyahKey key);
}
