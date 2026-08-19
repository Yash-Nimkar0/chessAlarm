import 'package:flutter_test/flutter_test.dart';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:wakle/features/alarms/domain/alarm_model.dart';
import 'package:wakle/features/alarms/domain/mission_config.dart';
import 'package:wakle/features/alarms/domain/recurrence.dart';
import 'package:wakle/features/alarms/application/alarm_controller.dart';
import 'package:wakle/features/alarms/data/alarm_repository.dart';
import 'package:wakle/features/alarms/data/alarm_scheduler.dart';

class MockAlarmScheduler extends AlarmScheduler {
  final Set<int> scheduledIds = {};

  @override
  Future<void> schedule(WakelyAlarm alarm) async {
    if (alarm.enabled) scheduledIds.add(alarm.id);
  }

  @override
  Future<void> cancel(int alarmId) async {
    scheduledIds.remove(alarmId);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({});

  late AlarmRepository repository;
  late MockAlarmScheduler scheduler;
  late AlarmController controller;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    repository = AlarmRepository();
    scheduler = MockAlarmScheduler();
    controller = AlarmController.test(repository, scheduler);
  });

  WakelyAlarm _buildAlarm({
    required AlarmType type, 
    required bool isOneShot, 
    required DateTime time
  }) {
    return WakelyAlarm(
      id: 0,
      time: time,
      enabled: true,
      type: type,
      recurrence: isOneShot ? Recurrence.none() : Recurrence(List.filled(7, true)),
      soundId: 'test',
      fadeIn: false,
      fadeDuration: 0,
      loopAudio: true,
      vibrate: true,
      volume: 1.0,
      smartLock: false,
      mission: MissionConfig(type: MissionType.none),
      sleepGoal: 8.0,
      sleepTracking: false,
      sleepSounds: false,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
  }

  group('Quick Alarm Lifecycle', () {
    test('Quick Alarm completion removes active persistence', () async {
      final alarm = _buildAlarm(
        type: AlarmType.quickAlarm, 
        isOneShot: true, 
        time: DateTime.now().add(const Duration(minutes: 5))
      );
      
      final created = await controller.createAlarm(alarm);
      expect(await repository.getById(created.id), isNotNull);

      // Complete the quick alarm
      await controller.completeAlarm(created.id);
      
      // Should be entirely deleted
      expect(await repository.getById(created.id), isNull);
    });

    test('Quick Alarm excluded from next-alarm queries', () async {
      final quick = _buildAlarm(
        type: AlarmType.quickAlarm, 
        isOneShot: true, 
        time: DateTime.now().add(const Duration(minutes: 5))
      );
      await controller.createAlarm(quick);

      // Wake routines filter
      final nextWake = await controller.getNextEnabledWakeRoutine();
      expect(nextWake, isNull);
    });
  });

  group('One-Shot Lifecycle', () {
    test('Completed one-shot not rescheduled to tomorrow on recovery', () async {
      final alarm = _buildAlarm(
        type: AlarmType.standard, 
        isOneShot: true, 
        time: DateTime.now().add(const Duration(minutes: 5))
      );
      final created = await controller.createAlarm(alarm);

      // Simulate time passing and the alarm completing
      await controller.completeAlarm(created.id);
      
      final disabledAlarm = await repository.getById(created.id);
      expect(disabledAlarm!.enabled, isFalse);
      
      // Attempting to reschedule it (e.g. restart) shouldn't invent tomorrow
      await controller.reschedule(created.id);
      
      final afterReschedule = await repository.getById(created.id);
      expect(afterReschedule!.enabled, isFalse);
      expect(afterReschedule.time, disabledAlarm.time); // Time didn't change to tomorrow
    });

    test('Stale enabled one-shot disabled on reschedule instead of inventing tomorrow', () async {
      final alarm = _buildAlarm(
        type: AlarmType.standard, 
        isOneShot: true, 
        time: DateTime.now().add(const Duration(minutes: 5))
      );
      final created = await controller.createAlarm(alarm);

      // Manually edit the DB to make it stale (simulate phone was off)
      final staleAlarm = created.copyWith(time: DateTime.now().subtract(const Duration(hours: 1)));
      await repository.save(staleAlarm);

      // System restart triggers reschedule
      await controller.reschedule(created.id);

      final recovered = await repository.getById(created.id);
      expect(recovered!.enabled, isFalse); // It should be safely disabled
    });
  });

  group('Idempotency', () {
    test('Enable/disable idempotency', () async {
      final alarm = _buildAlarm(
        type: AlarmType.standard, 
        isOneShot: false, 
        time: DateTime.now().add(const Duration(hours: 1))
      );
      final created = await controller.createAlarm(alarm);

      await controller.disableAlarm(created.id);
      final d1 = await repository.getById(created.id);
      expect(d1!.enabled, isFalse);

      await controller.disableAlarm(created.id);
      final d2 = await repository.getById(created.id);
      expect(d2!.enabled, isFalse); // No crash, no change

      await controller.enableAlarm(created.id);
      final e1 = await repository.getById(created.id);
      expect(e1!.enabled, isTrue);

      await controller.enableAlarm(created.id);
      final e2 = await repository.getById(created.id);
      expect(e2!.enabled, isTrue); // No crash, no duplicate logic run
    });

    test('Complete idempotency (recurring)', () async {
      final alarm = _buildAlarm(
        type: AlarmType.standard, 
        isOneShot: false, 
        time: DateTime.now().subtract(const Duration(minutes: 1)) // Past
      );
      final created = await controller.createAlarm(alarm);

      await controller.completeAlarm(created.id);
      final afterFirst = await repository.getById(created.id);
      
      await controller.completeAlarm(created.id);
      final afterSecond = await repository.getById(created.id);

      // It should calculate the exact same next occurrence for the same day
      expect(afterFirst!.time, equals(afterSecond!.time));
    });
  });
}
