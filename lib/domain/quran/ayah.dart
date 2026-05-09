import 'ayah_key.dart';

class Ayah {
  const Ayah({required this.key, required this.text});

  final AyahKey key;
  final String text;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Ayah && other.key == key && other.text == text;

  @override
  int get hashCode => Object.hash(key, text);
}
