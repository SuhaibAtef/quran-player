import '../../core/error/failure.dart';
import '../../core/error/result.dart';

class AyahKey {
  const AyahKey._(this.surah, this.ayah);

  factory AyahKey(int surah, int ayah) {
    if (surah < 1 || surah > 114) {
      throw ArgumentError.value(surah, 'surah', 'must be in 1..114');
    }
    if (ayah < 1) {
      throw ArgumentError.value(ayah, 'ayah', 'must be >= 1');
    }
    return AyahKey._(surah, ayah);
  }

  static Result<AyahKey> tryNew(int surah, int ayah) {
    if (surah < 1 || surah > 114) {
      return Result.err(InvalidInputFailure('surah out of range: $surah'));
    }
    if (ayah < 1) {
      return Result.err(InvalidInputFailure('ayah out of range: $ayah'));
    }
    return Result.ok(AyahKey._(surah, ayah));
  }

  static Result<AyahKey> parse(String input) {
    final trimmed = input.trim();
    final parts = trimmed.split(':');
    if (parts.length != 2) {
      return Result.err(
        InvalidInputFailure('expected "surah:ayah", got "$input"'),
      );
    }
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) {
      return Result.err(
        InvalidInputFailure('non-integer surah or ayah in "$input"'),
      );
    }
    return tryNew(surah, ayah);
  }

  final int surah;
  final int ayah;

  @override
  String toString() => '$surah:$ayah';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AyahKey && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);
}
