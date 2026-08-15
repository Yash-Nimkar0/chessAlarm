enum SoundSource {
  bundled,
  downloaded,
  custom,
}

class SoundModel {
  final String id;
  final String name;
  final SoundSource source;
  final String path;
  final bool isPremium;
  final String? category;

  const SoundModel({
    required this.id,
    required this.name,
    required this.source,
    required this.path,
    this.isPremium = false,
    this.category,
  });
}
