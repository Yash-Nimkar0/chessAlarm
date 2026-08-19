import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakle/features/alarms/domain/alarm_model.dart';
import 'package:wakle/features/alarms/domain/recurrence.dart';
import 'package:wakle/features/alarms/domain/platform_alarm_state.dart';
import 'package:wakle/features/alarms/data/alarm_repository.dart';
import 'package:wakle/features/alarms/data/alarm_scheduler.dart';
import 'package:wakle/features/alarms/application/alarm_controller.dart';
import 'package:alarm/alarm.dart';

// Same fake scheduler used in alarm_lifecycle_test.dart
class FakeAlarmScheduler extends AlarmScheduler {
  final List<WakelyAlarm> scheduledAlarms = [];
  final List<int> cancelledAlarms = [];

  @override
  Future<void> init() async {}

  @override
  Future<void> schedule(WakelyAlarm alarm) async {
    scheduledAlarms.add(alarm);
  }

  @override
  Future<void> cancel(int alarmId) async {
    cancelledAlarms.add(alarmId);
    scheduledAlarms.removeWhere((a) => a.id == alarmId);
  }

  @override
  Future<List<PlatformAlarmState>> getScheduledAlarms() async {
    return scheduledAlarms.map((a) => PlatformAlarmState(
      alarmId: a.id,
      nativeState: 'scheduled',
      scheduledAt: a.time,
    )).toList();
  }

  @override
  Future<bool> isScheduled(int alarmId) async {
    return scheduledAlarms.any((a) => a.id == alarmId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AlarmRepository repository;
  late FakeAlarmScheduler scheduler;
  late AlarmController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = AlarmRepository();
    scheduler = FakeAlarmScheduler();
    controller = AlarmController.test(repository, scheduler);
  });

  WakelyAlarm createBaseAlarm({
    required Recurrence recurrence,
    bool enabled = true,
    AlarmType type = AlarmType.standard,
    DateTime? time,
  }) {
    final now = DateTime.now();
    return WakelyAlarm(
      id: 0,
      time: time ?? now.add(const Duration(hours: 1)),
      enabled: enabled,
      type: type,
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('AlarmController Queries', () {
    test('disabled alarm excluded from next alarm', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none(), enabled: false);
      await controller.createAlarm(alarm);

      final next = await controller.getNextEnabledAlarm();
      expect(next, isNull);
    });

    test('Quick Alarm excluded from Wake Routine query', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none(), type: AlarmType.quickAlarm);
      await controller.createAlarm(alarm);

      final nextWake = await controller.getNextEnabledWakeRoutine();
      expect(nextWake, isNull);
    });

    test('Standard alarm excluded from Wake Routine query', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none(), type: AlarmType.standard);
      await controller.createAlarm(alarm);

      final nextWake = await controller.getNextEnabledWakeRoutine();
      expect(nextWake, isNull);
    });

    test('enabled Wake Routine selected correctly', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none(), type: AlarmType.wakeRoutine);
      await controller.createAlarm(alarm);

      final nextWake = await controller.getNextEnabledWakeRoutine();
      expect(nextWake, isNotNull);
      expect(nextWake!.alarm.type, AlarmType.wakeRoutine);
    });

    test('no enabled alarms -> no next alarm', () async {
      final next = await controller.getNextEnabledAlarm();
      expect(next, isNull);
    });

    test('no recurrence days -> correct one-shot behavior (excluded if time is past)', () async {
      // Create a one-shot alarm with a time in the past
      final pastTime = DateTime.now().subtract(const Duration(hours: 1));
      final alarm = createBaseAlarm(recurrence: Recurrence.none(), time: pastTime);
      
      // We manually save it to repository to bypass createAlarm's auto-advancing logic
      // to simulate the bug scenario where a past alarm stayed enabled.
      await repository.save(alarm);

      final next = await controller.getNextEnabledAlarm();
      expect(next, isNull); // Should not appear as next alarm because it's past and one-shot
    });

    test('recurring alarm whose stored time is in the past -> still finds its next recurrence', () async {
      final now = DateTime.now();
      // Suppose it's Mon 10:00, and alarm time is 07:00, Mon-Fri.
      // We simulate this by setting alarm time to 3 hours ago.
      final pastTime = now.subtract(const Duration(hours: 3));
      
      final alarm = createBaseAlarm(
        recurrence: Recurrence.everyday(),
        time: pastTime,
      );
      await repository.save(alarm);

      final next = await controller.getNextEnabledAlarm();
      expect(next, isNotNull);
      
      // Its next occurrence should be in the future (tomorrow at 7:00).
      expect(next!.nextOccurrence.isAfter(now), isTrue);
      expect(next.nextOccurrence.hour, pastTime.hour);
      expect(next.nextOccurrence.minute, pastTime.minute);
    });
  });
}
