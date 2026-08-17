import '../domain/sound_model.dart';

class SoundRepository {
  static final SoundRepository instance = SoundRepository._();

  SoundRepository._();

  final List<SoundModel> _bundledSounds = const [
    const SoundModel(
      id: 'wakely_ringphone',
      name: 'Ringphone',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/misogi77-ringphone-191692.mp3',
      category: 'Digital',
      durationSeconds: 18,
    ),
    const SoundModel(
      id: 'wakely_soft_morning',
      name: 'Soft Morning',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/marmixer-soft-morning-484625.mp3',
      category: 'Acoustic',
      durationSeconds: 72,
    ),
    const SoundModel(
      id: 'wakely_morning_sun',
      name: 'Morning Sun',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/ringy345xxx-morning-sun-morning-alarm-for-samsung-iphone-423087.mp3',
      category: 'Acoustic',
      durationSeconds: 34,
    ),
    const SoundModel(
      id: 'wakely_tropical',
      name: 'Tropical',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-tropical-alarm-clock-168821.mp3',
      category: 'Atmospheric',
      durationSeconds: 60,
    ),
    const SoundModel(
      id: 'wakely_celestial',
      name: 'Celestial',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-celestial-alarm-clock-386401.mp3',
      category: 'Atmospheric',
      durationSeconds: 69,
    ),
    const SoundModel(
      id: 'wakely_maze',
      name: 'Maze of Thoughts',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-maze-of-thoughts-alarm-clock-311402.mp3',
      category: 'Atmospheric',
      durationSeconds: 60,
    ),
    const SoundModel(
      id: 'wakely_gentle_guitar',
      name: 'Gentle Guitar',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/universfield-gentle-acoustic-guitar-143071.mp3',
      category: 'Acoustic',
      durationSeconds: 70,
    ),
    const SoundModel(
      id: 'wakely_hacker',
      name: 'Hacker',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/4379051-hacker-alarm-124960.mp3',
      category: 'Digital',
      isPremium: true,
      durationSeconds: 209,
    ),
    const SoundModel(
      id: 'wakely_eas',
      name: 'Emergency',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/jeremayjimenez-philippines-eas-alarm-1898-451405.mp3',
      category: 'Intense',
      isPremium: true,
      durationSeconds: 102,
    ),
    const SoundModel(
      id: 'wakely_chiptune',
      name: 'Chiptune',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/hauntsync-chiptune-alarm-ringtone-song-218038.mp3',
      category: 'Digital',
      isPremium: true,
      durationSeconds: 96,
    ),
    const SoundModel(
      id: 'wakely_kirby',
      name: 'Kirby',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-kirby-alarm-clock-127079.mp3',
      category: 'Digital',
      isPremium: true,
      durationSeconds: 60,
    ),
    const SoundModel(
      id: 'wakely_jingle',
      name: 'Jingle Bells',
      source: SoundSource.bundled,
      path: 'assets/audio/alarms/lesiakower-jingle-bells-alarm-clock-version-129333.mp3',
      category: 'Other',
      isPremium: true,
      durationSeconds: 51,
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

  /// Resolves the domain sound ID to the native iOS bundled filename for AlarmKit.
  /// 
  /// AlarmKit's `AlertConfiguration.AlertSound.named()` requires the exact filename 
  /// (with extension) of a file present in the Xcode "Copy Bundle Resources" phase.
  String getNativeIOSSoundFilename(String id) {
    switch (id) {
      case 'wakely_ringphone': return 'misogi77.wav';
      case 'wakely_soft_morning': return 'soft_morning.wav';
      case 'wakely_morning_sun': return 'morning_sun.wav';
      case 'wakely_tropical': return 'tropical.wav';
      case 'wakely_celestial': return 'celestial.wav';
      case 'wakely_maze': return 'maze.wav';
      case 'wakely_gentle_guitar': return 'gentle_guitar.wav';
      case 'wakely_hacker': return 'hacker.wav';
      case 'wakely_eas': return 'eas.wav';
      case 'wakely_chiptune': return 'chiptune.wav';
      case 'wakely_kirby': return 'kirby.wav';
      case 'wakely_jingle': return 'jingle.wav';
      default:
        // Log fallback and use the most generic system sound if ID is completely invalid
        print('WARNING: Sound $id not found in native mapping. Falling back to default ringphone.');
        return 'misogi77.wav'; 
    }
  }
}
