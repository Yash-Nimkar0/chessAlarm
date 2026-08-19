import 'package:flutter_test/flutter_test.dart';
import 'package:wakely/features/alarms/application/wake_audio_session_controller.dart';

void main() {
  group('WakeAudioSessionController.evaluateVolumeChange', () {
    test('pushes system volume back up when the user lowers it below the floor', () {
      // This is the actual "you cannot silence it with the volume button"
      // behavior requested to match Alarmy: while a wake session is
      // active, a drop below the established floor must be corrected.
      final decision = WakeAudioSessionController.evaluateVolumeChange(
        floor: 0.5,
        observedVolume: 0.1,
      );

      expect(decision.correctedValue, 0.5);
      expect(decision.newFloor, 0.5);
    });

    test('does not fight a deliberate volume increase, and raises the floor to match it', () {
      final decision = WakeAudioSessionController.evaluateVolumeChange(
        floor: 0.5,
        observedVolume: 0.9,
      );

      expect(decision.correctedValue, isNull, reason: 'Raising the volume must never be corrected.');
      expect(decision.newFloor, 0.9, reason: 'A deliberate raise becomes the new floor.');
    });

    test('a later attempt to drop back toward the original floor is still corrected once raised', () {
      final raised = WakeAudioSessionController.evaluateVolumeChange(floor: 0.5, observedVolume: 0.9);
      final droppedBack = WakeAudioSessionController.evaluateVolumeChange(
        floor: raised.newFloor,
        observedVolume: 0.6, // still above the original 0.5 floor
      );

      expect(droppedBack.correctedValue, 0.9,
          reason: 'Once the user proved they wanted 0.9, dropping to 0.6 must still be corrected back to 0.9.');
    });

    test('a value exactly at the floor is left alone (no correction feedback loop)', () {
      // This is what happens right after we push a correction: the
      // corrected value echoes back through the listener. It must not be
      // treated as "below the floor" again, or enforcement would loop.
      final decision = WakeAudioSessionController.evaluateVolumeChange(floor: 0.5, observedVolume: 0.5);

      expect(decision.correctedValue, isNull);
      expect(decision.newFloor, 0.5);
    });

    test('tiny float-precision differences at the floor do not trigger a correction', () {
      final decision = WakeAudioSessionController.evaluateVolumeChange(floor: 0.5, observedVolume: 0.499);
      expect(decision.correctedValue, isNull);
    });
  });
}
