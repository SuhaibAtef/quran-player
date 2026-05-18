import '../quran/ayah_key.dart';

/// The user's most recent reading position, persisted in `user.db`.
///
/// Exactly one is retained — the reader overwrites it whenever the user moves
/// through or leaves the reader.
class ReadingPosition {
  const ReadingPosition({required this.key, required this.updatedAt});

  /// The ayah the user was last reading.
  final AyahKey key;

  /// When the position was recorded (UTC).
  final DateTime updatedAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReadingPosition &&
          other.key == key &&
          other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(key, updatedAt);

  @override
  String toString() => 'ReadingPosition($key, updatedAt: $updatedAt)';
}
