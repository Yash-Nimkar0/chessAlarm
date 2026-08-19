import 'package:flutter_test/flutter_test.dart';
import 'package:wakle/features/sounds/data/sound_repository.dart';
import 'dart:io';

void main() {
  group('SoundRepository Mapping Tests', () {
    test('All bundled sounds have exact 1:1 iOS native mappings', () {
      final repo = SoundRepository.instance;
      final sounds = repo.getAvailableSounds();
      
      expect(sounds.length, 12, reason: 'Expected exactly 12 bundled sounds');

      for (final sound in sounds) {
        final nativeFilename = repo.getNativeIOSSoundFilename(sound.id);
        expect(nativeFilename, isNotEmpty, reason: 'Missing mapping for ${sound.id}');
        
        // Also ensure it is not defaulting to misogi77 unless it's the ringphone
        if (sound.id != 'wakely_ringphone') {
          expect(nativeFilename, isNot(equals('misogi77.wav')), reason: 'Sound ${sound.id} fell back to default ringphone');
        }
        
        // Verify the file physically exists in the iOS Runner directory
        final file = File('ios/Runner/$nativeFilename');
        expect(file.existsSync(), isTrue, reason: 'Native audio resource $nativeFilename is missing from ios/Runner/ for ${sound.id}');
      }
    });

    test('Unknown sound safely falls back to ringphone', () {
      final repo = SoundRepository.instance;
      final nativeFilename = repo.getNativeIOSSoundFilename('some_unknown_id');
      expect(nativeFilename, equals('misogi77.wav'));
    });
  });
}
