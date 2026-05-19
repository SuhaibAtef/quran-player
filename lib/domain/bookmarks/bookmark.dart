import '../quran/ayah_key.dart';

/// A user-saved pointer to a single ayah, persisted in `user.db`.
class Bookmark {
  const Bookmark({
    required this.id,
    required this.key,
    required this.createdAt,
  });

  /// Row id in the `bookmark` table. Null before the row is persisted.
  final int? id;

  /// The bookmarked ayah.
  final AyahKey key;

  /// When the bookmark was created (UTC).
  final DateTime createdAt;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Bookmark &&
          other.id == id &&
          other.key == key &&
          other.createdAt == createdAt;

  @override
  int get hashCode => Object.hash(id, key, createdAt);

  @override
  String toString() => 'Bookmark($key, createdAt: $createdAt)';
}
