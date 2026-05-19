class TafsirSource {
  const TafsirSource({
    required this.name,
    required this.publisher,
    required this.version,
    required this.url,
    required this.license,
    required this.retrievedAtUtc,
  });

  final String name;
  final String publisher;
  final String version;
  final String url;
  final String license;
  final DateTime retrievedAtUtc;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TafsirSource &&
          other.name == name &&
          other.publisher == publisher &&
          other.version == version &&
          other.url == url &&
          other.license == license &&
          other.retrievedAtUtc == retrievedAtUtc;

  @override
  int get hashCode =>
      Object.hash(name, publisher, version, url, license, retrievedAtUtc);
}
