import 'package:flutter_test/flutter_test.dart';
import 'package:wakle/services/notification_service.dart';
import 'package:wakle/features/alarms/domain/alarm_model.dart';
import 'package:wakle/features/alarms/domain/mission_config.dart';
import 'package:wakle/features/alarms/domain/recurrence.dart';

void main() {
  WakelyAlarm buildAlarm({
    required int id,
    bool enabled = true,
    AlarmType type = AlarmType.wakeRoutine,
    required DateTime time,
    double sleepGoal = 8.0,
  }) {
    return WakelyAlarm(
      id: id,
      time: time,
      enabled: enabled,
      type: type,
      mission: MissionConfig(type: MissionType.memory),
      recurrence: Recurrence.none(),
      sleepGoal: sleepGoal,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('NotificationService.remindersDue', () {
    final now = DateTime(2026, 8, 19, 12, 0);

    test('schedules a reminder for an enabled wakeRoutine alarm', () {
      // Regression: setupSleepReminders used to read from the legacy
      // `alarm` plugin's Alarm.getAlarms(), which AlarmKit-scheduled
      // alarms (the primary iOS 26.1+ path) never populate — so this would
      // silently compute zero reminders on that path. It must read from
      // AlarmController's unified WakelyAlarm repository instead (verified
      // separately at the setupSleepReminders call site); this tests the
      // actual selection/timing logic that was extracted alongside that fix.
      final alarm = buildAlarm(id: 701, time: now.add(const Duration(hours: 20)));

      final due = NotificationService.remindersDue([alarm], offsetMinutes: 0, now: now);

      expect(due, hasLength(1));
      expect(due.single.alarmId, 701);
      // wake at now+20h, sleepGoal 8h -> bedtime = now+12h, no offset.
      expect(due.single.reminderTime, now.add(const Duration(hours: 12)));
    });

    test('does not schedule a reminder for a disabled alarm', () {
      final alarm = buildAlarm(id: 702, enabled: false, time: now.add(const Duration(hours: 20)));
      expect(NotificationService.remindersDue([alarm], offsetMinutes: 0, now: now), isEmpty);
    });

    test('does not schedule a reminder for a non-wakeRoutine alarm', () {
      final alarm = buildAlarm(id: 703, type: AlarmType.standard, time: now.add(const Duration(hours: 20)));
      expect(NotificationService.remindersDue([alarm], offsetMinutes: 0, now: now), isEmpty);
    });

    test('does not schedule a reminder that would land in the past', () {
      // Wake alarm is only 2 hours away, but sleepGoal is 8 hours -> bedtime
      // computes to 6 hours in the past.
      final alarm = buildAlarm(id: 704, time: now.add(const Duration(hours: 2)));
      expect(NotificationService.remindersDue([alarm], offsetMinutes: 0, now: now), isEmpty);
    });

    test('applies the configured offset before bedtime', () {
      final alarm = buildAlarm(id: 705, time: now.add(const Duration(hours: 20)));
      final due = NotificationService.remindersDue([alarm], offsetMinutes: 30, now: now);
      expect(due.single.reminderTime, now.add(const Duration(hours: 12)).subtract(const Duration(minutes: 30)));
    });
  });
}
