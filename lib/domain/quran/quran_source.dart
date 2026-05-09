class QuranSource {
  const QuranSource({
    required this.name,
    required this.edition,
    required this.version,
    required this.url,
    required this.license,
    required this.retrievedAtUtc,
  });

  final String name;
  final String edition;
  final String version;
  final String url;
  final String license;
  final DateTime retrievedAtUtc;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is QuranSource &&
          other.name == name &&
          other.edition == edition &&
          other.version == version &&
          other.url == url &&
          other.license == license &&
          other.retrievedAtUtc == retrievedAtUtc;

  @override
  int get hashCode =>
      Object.hash(name, edition, version, url, license, retrievedAtUtc);
}
