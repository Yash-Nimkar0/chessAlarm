import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakle/features/alarms/domain/alarm_model.dart';
import 'package:wakle/features/alarms/domain/recurrence.dart';
import 'package:wakle/features/alarms/data/alarm_repository.dart';
import 'package:wakle/features/alarms/data/alarm_scheduler.dart';
import 'package:wakle/features/alarms/application/alarm_controller.dart';
import 'package:wakle/features/alarms/domain/platform_alarm_state.dart';

class FakeAlarmScheduler extends AlarmScheduler {
  final List<WakelyAlarm> scheduledAlarms = [];
  final List<int> cancelledAlarms = [];

  @override
  Future<void> init() async {}
  
  @override
  Future<void> schedule(WakelyAlarm alarm) async {
    // Mimic platform behavior: scheduling with same ID overwrites
    scheduledAlarms.removeWhere((a) => a.id == alarm.id);
    scheduledAlarms.add(alarm);
  }

  @override
  Future<void> cancel(int alarmId) async {
    scheduledAlarms.removeWhere((a) => a.id == alarmId);
    cancelledAlarms.add(alarmId);
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

  @override
  Future<void> cancelWakeCheckChain(int alarmId) async {}
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

  WakelyAlarm createBaseAlarm({required Recurrence recurrence}) {
    final now = DateTime.now();
    return WakelyAlarm(
      id: 0, // ID will be assigned by controller
      time: now.add(const Duration(hours: 1)),
      enabled: true,
      recurrence: recurrence,
      createdAt: now,
      updatedAt: now,
    );
  }

  group('Alarm Lifecycle invariants', () {
    test('create triggers exactly one schedule', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none());
      final created = await controller.createAlarm(alarm);
      
      expect(scheduler.scheduledAlarms, hasLength(1));
      expect(scheduler.scheduledAlarms.first.id, created.id);
    });

    test('duplicate save (update) does not duplicate platform alarm', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none());
      final created = await controller.createAlarm(alarm);
      
      // Update same alarm
      await controller.updateAlarm(created.copyWith(label: 'New'));
      
      // Should have cancelled the old one and scheduled exactly one new one
      expect(scheduler.scheduledAlarms, hasLength(1));
      expect(scheduler.scheduledAlarms.where((a) => a.id == created.id), hasLength(1));
      expect(scheduler.cancelledAlarms, contains(created.id));
    });

    test('disable removes platform schedule', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none());
      final created = await controller.createAlarm(alarm);
      
      expect(scheduler.scheduledAlarms, hasLength(1));
      
      await controller.disableAlarm(created.id);
      
      // Platform alarm cancelled
      expect(scheduler.scheduledAlarms, isEmpty);
      expect(scheduler.cancelledAlarms, contains(created.id));
      
      // Persistence retains alarm, but disabled
      final persisted = await repository.getById(created.id);
      expect(persisted!.enabled, isFalse);
    });

    test('duplicate disable is a no-op', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none());
      final created = await controller.createAlarm(alarm);
      
      await controller.disableAlarm(created.id);
      scheduler.cancelledAlarms.clear(); // reset tracking
      
      await controller.disableAlarm(created.id);
      
      // Shouldn't cancel again
      expect(scheduler.cancelledAlarms, isEmpty);
    });

    test('re-enable restores exactly one schedule', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none());
      final created = await controller.createAlarm(alarm);
      
      await controller.disableAlarm(created.id);
      await controller.enableAlarm(created.id);
      
      expect(scheduler.scheduledAlarms, hasLength(1));
      
      final persisted = await repository.getById(created.id);
      expect(persisted!.enabled, isTrue);
    });

    test('delete removes persistence and platform schedule', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none());
      final created = await controller.createAlarm(alarm);
      
      await controller.deleteAlarm(created.id);
      
      expect(scheduler.scheduledAlarms, isEmpty);
      expect(scheduler.cancelledAlarms, contains(created.id));
      
      final persisted = await repository.getById(created.id);
      expect(persisted, isNull);
    });

    test('complete one-shot alarm disables it and does not reschedule', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.none());
      final created = await controller.createAlarm(alarm);
      
      scheduler.scheduledAlarms.clear(); // simulate firing
      
      await controller.completeAlarm(created.id);
      
      expect(scheduler.scheduledAlarms, isEmpty); // Not rescheduled
      
      final persisted = await repository.getById(created.id);
      expect(persisted!.enabled, isFalse); // Disabled
    });

    test('complete recurring alarm reschedules exactly one next occurrence', () async {
      final alarm = createBaseAlarm(recurrence: Recurrence.everyday());
      final created = await controller.createAlarm(alarm);
      
      scheduler.scheduledAlarms.clear(); // simulate firing
      
      await controller.completeAlarm(created.id);
      
      // Should schedule exactly one new occurrence
      expect(scheduler.scheduledAlarms, hasLength(1));
      
      final rescheduled = scheduler.scheduledAlarms.first;
      
      // Should be scheduled for tomorrow (since afterFiring = true)
      final now = DateTime.now();
      expect(rescheduled.time.day, isNot(equals(now.day)));
      
      final persisted = await repository.getById(created.id);
      expect(persisted!.enabled, isTrue); // Stays enabled
    });
  });
}
