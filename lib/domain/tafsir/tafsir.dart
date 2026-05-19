import '../quran/ayah_key.dart';

class Tafsir {
  const Tafsir({required this.key, required this.text});

  final AyahKey key;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Tafsir && other.key == key && other.text == text;

  @override
  int get hashCode => Object.hash(key, text);

  @override
  String toString() => 'Tafsir($key, ${text.length} chars)';
}
