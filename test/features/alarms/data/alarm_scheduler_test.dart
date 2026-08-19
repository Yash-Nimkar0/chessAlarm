import 'package:flutter_test/flutter_test.dart';
import 'package:wakle/features/alarms/domain/alarm_model.dart';
import 'package:wakle/features/alarms/domain/recurrence.dart';
import 'package:wakle/features/alarms/data/alarm_scheduler.dart';

void main() {
  group('AlarmScheduler.nextOccurrence', () {
    final now = DateTime(2023, 10, 10, 12, 0); // Tuesday, Oct 10, 2023, 12:00 PM
    
    WakelyAlarm createAlarm(int hour, int minute, Recurrence recurrence) {
      return WakelyAlarm(
        id: 1,
        time: DateTime(now.year, now.month, now.day, hour, minute),
        recurrence: recurrence,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('one-shot alarm returns null', () {
      final alarm = createAlarm(14, 0, Recurrence.none());
      expect(AlarmScheduler.nextOccurrence(alarm, now), isNull);
    });

    test('same-day future returns today', () {
      // Alarm is at 2:00 PM, now is 12:00 PM on Tuesday. Recurrence includes Tuesday (index 1).
      final alarm = createAlarm(14, 0, Recurrence([false, true, false, false, false, false, false]));
      final next = AlarmScheduler.nextOccurrence(alarm, now);
      
      expect(next, isNotNull);
      expect(next!.year, 2023);
      expect(next.month, 10);
      expect(next.day, 10);
      expect(next.hour, 14);
    });

    test('same-day past advances to next week if only one day selected', () {
      // Alarm is at 10:00 AM, now is 12:00 PM on Tuesday. Recurrence only on Tuesday.
      final alarm = createAlarm(10, 0, Recurrence([false, true, false, false, false, false, false]));
      final next = AlarmScheduler.nextOccurrence(alarm, now);
      
      expect(next, isNotNull);
      expect(next!.year, 2023);
      expect(next.month, 10);
      expect(next.day, 17); // Next Tuesday
      expect(next.hour, 10);
    });

    test('same-day past advances to tomorrow if tomorrow is selected', () {
      // Alarm is at 10:00 AM, now is 12:00 PM on Tuesday. Recurrence Tue, Wed.
      final alarm = createAlarm(10, 0, Recurrence([false, true, true, false, false, false, false]));
      final next = AlarmScheduler.nextOccurrence(alarm, now);
      
      expect(next, isNotNull);
      expect(next!.year, 2023);
      expect(next.month, 10);
      expect(next.day, 11); // Wednesday
      expect(next.hour, 10);
    });

    test('midnight edge case', () {
      // Alarm is at 00:00 (midnight), now is 12:00 PM on Tuesday.
      // 00:00 is in the past for today. Next occurrence is Wed.
      final alarm = createAlarm(0, 0, Recurrence.everyday());
      final next = AlarmScheduler.nextOccurrence(alarm, now);
      
      expect(next, isNotNull);
      expect(next!.day, 11); // Tomorrow
      expect(next.hour, 0);
      expect(next.minute, 0);
    });

    test('afterFiring always advances past today', () {
      // Alarm is at 2:00 PM, now is 12:00 PM on Tuesday.
      // Usually this would fire today.
      final alarm = createAlarm(14, 0, Recurrence.everyday());
      
      // But if we say it just fired (maybe user manually triggered or time got weird):
      final next = AlarmScheduler.nextOccurrence(alarm, now, afterFiring: true);
      
      expect(next, isNotNull);
      expect(next!.day, 11); // Tomorrow
      expect(next.hour, 14);
    });

    test('Sunday to Monday wrap around', () {
      final sunday = DateTime(2023, 10, 15, 12, 0); // Sunday
      // Alarm at 10:00 AM (past) on Sunday. Recurrence is Monday only.
      final alarm = WakelyAlarm(
        id: 1,
        time: DateTime(sunday.year, sunday.month, sunday.day, 10, 0),
        recurrence: Recurrence([true, false, false, false, false, false, false]),
        createdAt: sunday,
        updatedAt: sunday,
      );
      
      final next = AlarmScheduler.nextOccurrence(alarm, sunday);
      
      expect(next, isNotNull);
      expect(next!.day, 16); // Monday
    });
  });

  group('AlarmScheduler.calculateFireTime', () {
    final now = DateTime(2023, 10, 10, 12, 0);
    
    test('one-shot past stays exactly as requested', () {
      final alarm = WakelyAlarm(
        id: 1,
        time: DateTime(now.year, now.month, now.day, 10, 0), // 10 AM, now is 12 PM
        recurrence: Recurrence.none(),
        createdAt: now,
        updatedAt: now,
      );
      
      final fireTime = AlarmScheduler.calculateFireTime(alarm, now);
      
      expect(fireTime.day, 10);
      expect(fireTime.hour, 10);
    });

    test('one-shot future stays today', () {
      final alarm = WakelyAlarm(
        id: 1,
        time: DateTime(now.year, now.month, now.day, 14, 0), // 2 PM, now is 12 PM
        recurrence: Recurrence.none(),
        createdAt: now,
        updatedAt: now,
      );
      
      final fireTime = AlarmScheduler.calculateFireTime(alarm, now);
      
      expect(fireTime.day, 10);
      expect(fireTime.hour, 14);
    });
  });
}
