enum Revelation { meccan, medinan }

class Surah {
  const Surah({
    required this.number,
    required this.nameArabic,
    required this.nameLatin,
    required this.revelation,
    required this.ayahCount,
  });

  final int number;
  final String nameArabic;
  final String nameLatin;
  final Revelation revelation;
  final int ayahCount;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Surah &&
          other.number == number &&
          other.nameArabic == nameArabic &&
          other.nameLatin == nameLatin &&
          other.revelation == revelation &&
          other.ayahCount == ayahCount;

  @override
  int get hashCode =>
      Object.hash(number, nameArabic, nameLatin, revelation, ayahCount);
}
