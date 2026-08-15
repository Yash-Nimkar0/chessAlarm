import 'package:flutter_test/flutter_test.dart';
import 'package:wakely/features/alarms/domain/alarm_model.dart';
import 'package:wakely/features/alarms/domain/mission_config.dart';
import 'package:wakely/features/alarms/domain/recurrence.dart';

void main() {
  group('MissionType', () {
    test('fromString handles valid types', () {
      expect(MissionType.fromString('math'), MissionType.math);
      expect(MissionType.fromString('memory'), MissionType.memory);
      expect(MissionType.fromString('qr'), MissionType.qr);
    });

    test('fromString handles invalid types with safe default', () {
      expect(MissionType.fromString('invalid_type'), MissionType.none);
    });
  });

  group('AlarmType', () {
    test('fromString handles valid types', () {
      expect(AlarmType.fromString('wakeRoutine'), AlarmType.wakeRoutine);
      expect(AlarmType.fromString('alarm'), AlarmType.standard);
    });

    test('fromString handles legacy chess type', () {
      expect(AlarmType.fromString('chess'), AlarmType.wakeRoutine);
    });
  });

  group('Recurrence', () {
    test('isOneShot is true when no days selected', () {
      final rec = Recurrence.none();
      expect(rec.isOneShot, isTrue);
    });

    test('isEveryday is true when all days selected', () {
      final rec = Recurrence.everyday();
      expect(rec.isEveryday, isTrue);
    });

    test('isWeekdaysOnly is true for Mon-Fri', () {
      final rec = Recurrence([true, true, true, true, true, false, false]);
      expect(rec.isWeekdaysOnly, isTrue);
    });

    test('displayText formats correctly', () {
      expect(Recurrence.none().displayText, 'Once');
      expect(Recurrence.everyday().displayText, 'Every day');
      expect(Recurrence([true, true, true, true, true, false, false]).displayText, 'Weekdays');
      expect(Recurrence([true, false, true, false, false, false, false]).displayText, 'Mon, Wed');
    });

    test('equality checks', () {
      final rec1 = Recurrence([true, false, false, false, false, false, false]);
      final rec2 = Recurrence([true, false, false, false, false, false, false]);
      final rec3 = Recurrence.none();
      
      expect(rec1, equals(rec2));
      expect(rec1, isNot(equals(rec3)));
    });
  });

  group('WakelyAlarm', () {
    final sampleDate = DateTime(2023, 1, 1, 8, 30);
    
    final sampleAlarm = WakelyAlarm(
      id: 42,
      time: sampleDate,
      enabled: true,
      type: AlarmType.wakeRoutine,
      recurrence: Recurrence([true, true, true, true, true, false, false]),
      label: 'Morning Workout',
      mission: const MissionConfig(
        type: MissionType.math,
        difficultyMode: 'hard',
        rounds: 3,
      ),
      createdAt: sampleDate,
      updatedAt: sampleDate,
    );

    test('toJson and fromJson roundtrip', () {
      final json = sampleAlarm.toJson();
      final decoded = WakelyAlarm.fromJson(json);

      expect(decoded.id, sampleAlarm.id);
      expect(decoded.time, sampleAlarm.time);
      expect(decoded.enabled, sampleAlarm.enabled);
      expect(decoded.type, sampleAlarm.type);
      expect(decoded.recurrence, sampleAlarm.recurrence);
      expect(decoded.label, sampleAlarm.label);
      expect(decoded.soundId, sampleAlarm.soundId);
      expect(decoded.fadeIn, sampleAlarm.fadeIn);
      expect(decoded.fadeDuration, sampleAlarm.fadeDuration);
      expect(decoded.mission, sampleAlarm.mission);
    });

    test('isLocked correctly identifies locked status', () {
      final now = DateTime.now();
      
      // Locked: smartLock is true, time is 1 min in the future
      final lockedAlarm = WakelyAlarm(
        id: 1,
        time: now.add(const Duration(minutes: 1)),
        smartLock: true,
        recurrence: Recurrence.none(),
        createdAt: now,
        updatedAt: now,
      );
      expect(lockedAlarm.isLocked, isTrue);

      // Not locked: smartLock is false
      final unlockedAlarm1 = lockedAlarm.copyWith(smartLock: false);
      expect(unlockedAlarm1.isLocked, isFalse);

      // Not locked: time is > 2 mins in the future
      final unlockedAlarm2 = lockedAlarm.copyWith(time: now.add(const Duration(minutes: 5)));
      expect(unlockedAlarm2.isLocked, isFalse);

      // Not locked: time is in the past
      final unlockedAlarm3 = lockedAlarm.copyWith(time: now.subtract(const Duration(minutes: 1)));
      expect(unlockedAlarm3.isLocked, isFalse);
    });
  });
}
