import 'package:flutter_test/flutter_test.dart';
import 'package:wakle/features/sounds/data/sound_repository.dart';
import 'package:wakle/features/sounds/domain/sound_model.dart';

void main() {
  group('SoundRepository', () {
    test('getAvailableSounds returns bundled sounds', () {
      final sounds = SoundRepository.instance.getAvailableSounds();
      expect(sounds, isNotEmpty);
      expect(sounds.any((s) => s.id == 'wakely_soft_morning'), isTrue);
    });

    test('getSoundById returns correct sound', () {
      final sound = SoundRepository.instance.getSoundById('wakely_celestial');
      expect(sound, isNotNull);
      expect(sound!.name, 'Celestial');
      expect(sound.source, SoundSource.bundled);
    });

    test('getSoundById returns null for unknown ID', () {
      final sound = SoundRepository.instance.getSoundById('unknown_id_123');
      expect(sound, isNull);
    });

    test('resolveLegacyPath maps old paths to new IDs', () {
      expect(SoundRepository.instance.resolveLegacyPath('assets/audio/alarms/marmixer-soft-morning-484625.mp3'), 'wakely_soft_morning');
      // Regression: resolveLegacyPath used to unconditionally return
      // 'wakely_soft_morning' for every input, silently resetting every
      // migrated user's sound choice to the default regardless of what
      // they'd actually configured. These two must resolve to their own
      // distinct IDs, not both collapse to the default.
      expect(SoundRepository.instance.resolveLegacyPath('assets/audio/alarms/lesiakower-celestial-alarm-clock-386401.mp3'), 'wakely_celestial');
      expect(SoundRepository.instance.resolveLegacyPath('assets/audio/alarms/misogi77-ringphone-191692.mp3'), 'wakely_ringphone');
    });

    test('resolveLegacyPath falls back to soft_morning for unknown paths', () {
      expect(SoundRepository.instance.resolveLegacyPath('assets/unknown.mp3'), 'wakely_soft_morning');
      expect(SoundRepository.instance.resolveLegacyPath('foo'), 'wakely_soft_morning');
    });
  });
}
