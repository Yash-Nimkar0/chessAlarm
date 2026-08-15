import '../domain/sound_model.dart';

class SoundRepository {
  static final SoundRepository instance = SoundRepository._();

  SoundRepository._();

  final List<SoundModel> _bundledSounds = const [
    SoundModel(
      id: 'wakely_ringphone',
      name: 'Ringphone',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/misogi77-ringphone-191692.mp3',
      category: 'Classic',
    ),
    SoundModel(
      id: 'wakely_soft_morning',
      name: 'Soft Morning',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/marmixer-soft-morning-484625.mp3',
      category: 'Nature / Morning',
    ),
    SoundModel(
      id: 'wakely_morning_sun',
      name: 'Morning Sun',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/ringy345xxx-morning-sun-morning-alarm-for-samsung-iphone-423087.mp3',
      category: 'Nature / Morning',
    ),
    SoundModel(
      id: 'wakely_tropical',
      name: 'Tropical',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-tropical-alarm-clock-168821.mp3',
      category: 'Nature / Morning',
    ),
    SoundModel(
      id: 'wakely_celestial',
      name: 'Celestial',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-celestial-alarm-clock-386401.mp3',
      category: 'Calm',
    ),
    SoundModel(
      id: 'wakely_maze',
      name: 'Maze of Thoughts',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-maze-of-thoughts-alarm-clock-311402.mp3',
      category: 'Calm',
    ),
    SoundModel(
      id: 'wakely_gentle_guitar',
      name: 'Gentle Guitar',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/universfield-gentle-acoustic-guitar-143071.mp3',
      category: 'Calm',
    ),
    SoundModel(
      id: 'wakely_hacker',
      name: 'Hacker',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/4379051-hacker-alarm-124960.mp3',
      category: 'Energetic',
    ),
    SoundModel(
      id: 'wakely_eas',
      name: 'Gentle Melody',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/jeremayjimenez-philippines-eas-alarm-1898-451405.mp3',
      category: 'Calm / Morning',
    ),
    SoundModel(
      id: 'wakely_chiptune',
      name: 'Chiptune',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/hauntsync-chiptune-alarm-ringtone-song-218038.mp3',
      category: 'Unique',
    ),
    SoundModel(
      id: 'wakely_kirby',
      name: 'Kirby',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-kirby-alarm-clock-127079.mp3',
      category: 'Unique',
    ),
    SoundModel(
      id: 'wakely_jingle_bells',
      name: 'Jingle Bells',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-jingle-bells-alarm-clock-version-129333.mp3',
      category: 'Unique',
    ),
  ];

  List<SoundModel> getAvailableSounds() {
    return _bundledSounds;
  }

  SoundModel? getSoundById(String id) {
    for (final sound in _bundledSounds) {
      if (sound.id == id) {
        return sound;
      }
    }
    return null;
  }

  /// Resolves legacy asset paths to the new sound ID architecture.
  String resolveLegacyPath(String path) {
    // Fallback for all unknown and legacy sounds
    return 'wakely_soft_morning';
  }
}
