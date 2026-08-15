import 'dart:async';
import '../domain/alarm_model.dart';
import '../data/alarm_repository.dart';
import '../data/alarm_scheduler.dart';
import '../data/alarm_id_allocator.dart';

import 'package:flutter/foundation.dart';

/// Application layer controller for Alarms.
///
/// This is the primary API for screens to interact with alarms.
/// It coordinates persistence ([AlarmRepository]) and platform scheduling
/// ([AlarmScheduler]) to maintain the core invariant:
///
/// For a disabled alarm:
/// - persistence: alarm exists, enabled = false
/// - platform: alarm is NOT scheduled
///
/// For an enabled alarm:
/// - persistence: enabled = true
/// - platform: exactly one schedule exists
class AlarmController extends ChangeNotifier {
  final AlarmRepository _repository;
  final AlarmScheduler _scheduler;

  // Singleton instance for easy access across the app
  static final AlarmController instance = AlarmController._(
    AlarmRepository(),
    AlarmScheduler(),
  );

  AlarmController._(this._repository, this._scheduler);

  /// For dependency injection in tests
  AlarmController.test(this._repository, this._scheduler);

  /// Retrieve all alarms from the repository.
  Future<List<WakelyAlarm>> getAlarms() async {
    return await _repository.getAll();
  }

  /// Retrieve a specific alarm by ID.
  Future<WakelyAlarm?> getAlarm(int id) async {
    return await _repository.getById(id);
  }

  /// Get the absolute next scheduled alarm across all enabled alarms.
  Future<ScheduledAlarm?> getNextEnabledAlarm() async {
    final alarms = await getAlarms();
    return _findNext(alarms, null);
  }

  /// Get the next scheduled wake routine alarm specifically.
  Future<ScheduledAlarm?> getNextEnabledWakeRoutine() async {
    final alarms = await getAlarms();
    return _findNext(alarms, AlarmType.wakeRoutine);
  }

  ScheduledAlarm? _findNext(List<WakelyAlarm> alarms, AlarmType? typeFilter) {
    final now = DateTime.now();
    ScheduledAlarm? bestCandidate;

    for (final alarm in alarms) {
      if (!alarm.enabled) continue;
      if (typeFilter != null && alarm.type != typeFilter) continue;

      DateTime? occurrence;
      if (alarm.recurrence.isOneShot) {
        if (alarm.time.isAfter(now)) {
          occurrence = alarm.time;
        }
      } else {
        occurrence = AlarmScheduler.nextOccurrence(alarm, now);
      }

      if (occurrence != null) {
        if (bestCandidate == null || occurrence.isBefore(bestCandidate.nextOccurrence)) {
          bestCandidate = ScheduledAlarm(alarm, occurrence);
        }
      }
    }
    return bestCandidate;
  }

  /// Create a new alarm.
  ///
  /// Allocates a new ID, schedules it if enabled, and persists it.
  Future<WakelyAlarm> createAlarm(WakelyAlarm alarm) async {
    final newId = await AlarmIdAllocator.allocate();
    
    // Set ID and calculate initial fire time
    final alarmWithId = alarm.copyWith(id: newId);
    final fireTime = AlarmScheduler.calculateFireTime(alarmWithId, DateTime.now());
    
    final finalAlarm = alarmWithId.copyWith(time: fireTime);

    if (finalAlarm.enabled) {
      await _scheduler.schedule(finalAlarm);
    }
    
    final saved = await _repository.save(finalAlarm);
    notifyListeners();
    return saved;
  }

  /// Update an existing alarm.
  ///
  /// Cancels the old schedule (if any), calculates the new fire time,
  /// schedules it if enabled, and updates persistence.
  Future<WakelyAlarm> updateAlarm(WakelyAlarm alarm) async {
    // 1. Cancel existing schedule to prevent duplicates
    await _scheduler.cancel(alarm.id);

    // 2. Calculate new fire time based on updated properties
    final fireTime = AlarmScheduler.calculateFireTime(alarm, DateTime.now());
    final finalAlarm = alarm.copyWith(time: fireTime, updatedAt: DateTime.now());

    // 3. Schedule if enabled
    if (finalAlarm.enabled) {
      await _scheduler.schedule(finalAlarm);
    }

    // 4. Save to repository
    final saved = await _repository.save(finalAlarm);
    notifyListeners();
    return saved;
  }

  /// Delete an alarm.
  ///
  /// Cancels the schedule and removes it from persistence.
  Future<void> deleteAlarm(int id) async {
    await _scheduler.cancel(id);
    await _repository.delete(id);
    notifyListeners();
  }

  /// Enable a disabled alarm.
  ///
  /// Calculates the next valid fire time, schedules it, and updates persistence.
  Future<void> enableAlarm(int id) async {
    final alarm = await _repository.getById(id);
    if (alarm == null || alarm.enabled) return;

    if (alarm.recurrence.isOneShot && alarm.time.isBefore(DateTime.now())) {
      // Prevent silently scheduling a past one-shot alarm for tomorrow.
      return;
    }

    final fireTime = AlarmScheduler.calculateFireTime(alarm, DateTime.now());
    final updatedAlarm = alarm.copyWith(enabled: true, time: fireTime, updatedAt: DateTime.now());

    await _scheduler.schedule(updatedAlarm);
    await _repository.save(updatedAlarm);
    notifyListeners();
  }

  /// Disable an enabled alarm.
  ///
  /// Cancels the schedule and updates persistence.
  Future<void> disableAlarm(int id) async {
    final alarm = await _repository.getById(id);
    if (alarm == null || !alarm.enabled) return;

    await _scheduler.cancel(id);

    final updatedAlarm = alarm.copyWith(enabled: false, updatedAt: DateTime.now());
    await _repository.save(updatedAlarm);
    notifyListeners();
  }

  /// Handle an alarm completing (e.g. user dismissed it or completed mission).
  ///
  /// For one-shot alarms: disables the alarm.
  /// For recurring alarms: calculates the next occurrence and reschedules.
  Future<void> completeAlarm(int id) async {
    final alarm = await _repository.getById(id);
    if (alarm == null) return;

    // Always cancel current first to prevent any race conditions or duplicates
    await _scheduler.cancel(id);

    if (alarm.recurrence.isOneShot) {
      final updatedAlarm = alarm.copyWith(enabled: false, updatedAt: DateTime.now());
      await _repository.save(updatedAlarm);
    } else {
      // It's recurring, so reschedule for the next occurrence AFTER today.
      final nextTime = AlarmScheduler.nextOccurrence(alarm, DateTime.now(), afterFiring: true);
      
      if (nextTime != null) {
        final updatedAlarm = alarm.copyWith(time: nextTime, updatedAt: DateTime.now());
        await _scheduler.schedule(updatedAlarm);
        await _repository.save(updatedAlarm);
      } else {
        // Fallback in case recurrence was corrupted
        final updatedAlarm = alarm.copyWith(enabled: false, updatedAt: DateTime.now());
        await _repository.save(updatedAlarm);
      }
    }
    notifyListeners();
  }

  /// Reschedule an alarm without enabling/disabling.
  /// Used primarily during system restarts or time changes.
  Future<void> reschedule(int id) async {
    final alarm = await _repository.getById(id);
    if (alarm == null) return;
    
    // Always cancel before scheduling to guarantee exactly one platform alarm
    await _scheduler.cancel(id);
    
    if (alarm.enabled) {
      // Recalculate fire time in case we missed it while offline
      final fireTime = AlarmScheduler.calculateFireTime(alarm, DateTime.now());
      final updatedAlarm = alarm.copyWith(time: fireTime, updatedAt: DateTime.now());
      
      await _scheduler.schedule(updatedAlarm);
      await _repository.save(updatedAlarm);
    }
  }
}
