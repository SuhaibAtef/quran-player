import 'package:quran_player/core/error/result.dart';
import 'package:quran_player/domain/bookmarks/bookmark.dart';
import 'package:quran_player/domain/bookmarks/bookmark_repository.dart';
import 'package:quran_player/domain/quran/ayah_key.dart';
import 'package:quran_player/domain/reading/reading_position.dart';
import 'package:quran_player/domain/reading/reading_position_repository.dart';

/// In-memory [BookmarkRepository] for widget tests.
class FakeBookmarkRepository implements BookmarkRepository {
  FakeBookmarkRepository({List<AyahKey> initial = const []}) {
    for (final key in initial) {
      _items.add(
        Bookmark(id: _nextId++, key: key, createdAt: DateTime.now().toUtc()),
      );
    }
  }

  final List<Bookmark> _items = [];
  int _nextId = 1;

  @override
  Future<Result<List<Bookmark>>> list() async {
    final sorted = [..._items]
      ..sort((a, b) => (b.id ?? 0).compareTo(a.id ?? 0));
    return Result.ok(sorted);
  }

  @override
  Future<Result<Bookmark>> add(AyahKey key) async {
    final existing = _items.where((b) => b.key == key).toList();
    if (existing.isNotEmpty) return Result.ok(existing.first);
    final bookmark = Bookmark(
      id: _nextId++,
      key: key,
      createdAt: DateTime.now().toUtc(),
    );
    _items.add(bookmark);
    return Result.ok(bookmark);
  }

  @override
  Future<Result<bool>> remove(AyahKey key) async {
    final before = _items.length;
    _items.removeWhere((b) => b.key == key);
    return Result.ok(_items.length < before);
  }

  @override
  Future<Result<bool>> isBookmarked(AyahKey key) async =>
      Result.ok(_items.any((b) => b.key == key));
}

/// In-memory [ReadingPositionRepository] for widget tests.
class FakeReadingPositionRepository implements ReadingPositionRepository {
  FakeReadingPositionRepository([AyahKey? initial])
    : _position = initial == null
          ? null
          : ReadingPosition(key: initial, updatedAt: DateTime.now().toUtc());

  ReadingPosition? _position;

  @override
  Future<Result<ReadingPosition?>> load() async => Result.ok(_position);

  @override
  Future<Result<ReadingPosition>> save(AyahKey key) async {
    final pos = ReadingPosition(key: key, updatedAt: DateTime.now().toUtc());
    _position = pos;
    return Result.ok(pos);
  }
}
