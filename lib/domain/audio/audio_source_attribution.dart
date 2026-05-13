class AudioSourceAttribution {
  const AudioSourceAttribution({
    required this.providerName,
    required this.providerUrl,
    required this.terms,
    required this.attribution,
    required this.requiresAuth,
  });

  final String providerName;
  final String providerUrl;
  final String terms;
  final String attribution;
  final bool requiresAuth;
}
