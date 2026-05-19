class Reciter {
  const Reciter({
    required this.id,
    required this.sourceId,
    required this.name,
    required this.style,
    this.imageUri,
  });

  final String id;
  final int sourceId;
  final String name;
  final String style;
  final Uri? imageUri;
}
