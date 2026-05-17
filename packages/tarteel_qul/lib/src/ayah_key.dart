import 'package:flutter/foundation.dart';

/// A surah/ayah coordinate pair.
///
/// The engine uses [AyahKey] as the unit of its page↔ayah coordinate API and
/// as the payload of `MushafView`'s ayah-tap event. It is deliberately a plain
/// value type with no range validation — the coordinate API reports
/// out-of-range input as a structured failure rather than throwing at
/// construction, so an out-of-range key must be constructible to be queried.
@immutable
class AyahKey {
  const AyahKey(this.surah, this.ayah);

  /// 1-based surah number (1..114 for the canonical mushaf).
  final int surah;

  /// 1-based ayah number within the surah.
  final int ayah;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AyahKey && other.surah == surah && other.ayah == ayah;

  @override
  int get hashCode => Object.hash(surah, ayah);

  @override
  String toString() => 'AyahKey($surah:$ayah)';
}
