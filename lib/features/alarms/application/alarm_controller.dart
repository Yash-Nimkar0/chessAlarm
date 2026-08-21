import 'dart:async';
import 'package:alarm/alarm.dart';
import '../domain/alarm_model.dart';
import '../data/alarm_repository.dart';
import '../data/alarm_scheduler.dart';
import '../data/alarm_id_allocator.dart';
import '../domain/alarm_event.dart';
import '../domain/platform_alarm_state.dart';
import '../data/alarm_kit_uuid.dart';
import '../domain/wake_check_id.dart';
import 'wake_session_controller.dart';
import '../../../services/alarm_announcement_service.dart';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  // Platform event channel for AlarmKit native interactions
  static const EventChannel _eventChannel = EventChannel('wakely.alarmkit.events');

  // Short and limited by design - this app's re-alert chain is deliberately
  // relentless; snooze is a small, bounded escape hatch, not a way to
  // indefinitely defer waking up.
  static const int maxSnoozesPerRing = 2;
  static const Duration snoozeDuration = Duration(minutes: 5);
  final Map<int, int> _snoozeCounts = {};

  /// How many more times [id] can still be snoozed during its current ring
  /// cycle. Resets to [maxSnoozesPerRing] once the alarm is genuinely
  /// completed (see [completeAlarm]).
  int remainingSnoozes(int id) => (maxSnoozesPerRing - (_snoozeCounts[id] ?? 0)).clamp(0, maxSnoozesPerRing);

  /// Defers [id]'s native fire time by [snoozeDuration]. Purely a native
  /// reschedule under the same alarm id - the alarm's own configured time
  /// and recurrence in storage are left untouched, so its real next
  /// occurrence is computed correctly once it's genuinely completed rather
  /// than drifting to whatever time it last snoozed to. Returns false
  /// without doing anything once [maxSnoozesPerRing] is used up, or if the
  /// alarm can't be found.
  Future<bool> snoozeAlarm(int id) async {
    final used = _snoozeCounts[id] ?? 0;
    if (used >= maxSnoozesPerRing) return false;
    // Reserve the slot synchronously, before any `await` - a rapid
    // double-tap that calls this twice would otherwise have both calls
    // read the same stale `used` (both awaits start from the same
    // pre-increment state), both pass the limit check, and both
    // independently cancel+reschedule the native alarm, while the counter
    // only ever advanced by 1. Incrementing here, with no suspension point
    // between the check and the write, closes that window.
    _snoozeCounts[id] = used + 1;

    final alarm = await _repository.getById(id);
    if (alarm == null) {
      _snoozeCounts[id] = used; // nothing was scheduled - give the slot back
      return false;
    }

    await _scheduler.cancel(id);
    await _scheduler.schedule(alarm.copyWith(time: DateTime.now().add(snoozeDuration)));
    // This ring session is over - the next firing (in `snoozeDuration`) is a
    // fresh one and should speak its ring announcement again rather than
    // staying silent because of the earlier firing's dedupe window.
    AlarmAnnouncementService.clearDedupe(id);
    return true;
  }

  // Singleton instance for easy access across the app
  static final AlarmController instance = AlarmController._(
    AlarmRepository(),
    AlarmScheduler(),
  );

  AlarmController._(this._repository, this._scheduler);

  /// For dependency injection in tests
  AlarmController.test(this._repository, this._scheduler);

  /// Initialize the controller and listen for native interactions (e.g., AlarmKit).
  Future<void> init() async {
    // 1. Initialize the correct platform scheduler based on OS capabilities
    await _scheduler.init();

    // 2. Setup native bridge for AlarmKit (iOS 26+)
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final channel = const MethodChannel('wakely.alarmkit');

      // 3. Establish native `alarmUpdates` subscription early so we don't miss anything
      _eventChannel.receiveBroadcastStream().listen(_handleNativeEvent, onError: (e) {
        debugPrint('AlarmKit event channel error: $e');
      });

      // 4. Fetch pending cold-start interactions
      int? pendingInteractionId;
      try {
        final pendingId = await channel.invokeMethod<String>('getPendingAlarmInteraction');
        if (pendingId != null) {
          pendingInteractionId = int.tryParse(pendingId);
        }
      } catch (e) {
        debugPrint('Error getting pending interaction: $e');
      }

      // 5. Query native AlarmKit state
      final nativeAlarms = await _scheduler.getScheduledAlarms();

      // 6. & 7. Perform DB vs Native Reconciliation and WakeSession Recovery
      await _reconcile(nativeAlarms);

      // 8. Route pending interaction if any
      if (pendingInteractionId != null) {
        _routeNativeEvent(pendingInteractionId, AlarmNativeState.unknown, AlarmInteractionType.stop);
      }
    } else {
      // Legacy Android/iOS behavior: still reconcile local vs native based on plugin state
      final nativeAlarms = await _scheduler.getScheduledAlarms();
      await _reconcile(nativeAlarms);
    }
  }

  void _handleNativeEvent(dynamic event) {
    if (event is Map) {
      final type = event['type'];
      
      if (type == 'interaction') {
        final id = int.tryParse(event['alarmId'] as String? ?? '');
        if (id != null) {
          _routeNativeEvent(id, AlarmNativeState.unknown, AlarmInteractionType.stop);
        }
      } else if (type == 'interactionOpenWakely') {
        final id = int.tryParse(event['alarmId'] as String? ?? '');
        if (id != null) {
          _routeNativeEvent(id, AlarmNativeState.unknown, AlarmInteractionType.openWakely);
        }
      } else if (type == 'update') {
        final alarms = event['alarms'] as List<dynamic>?;
        if (alarms != null) {
          for (final alarmData in alarms) {
            if (alarmData is Map) {
              final idStr = alarmData['id'] as String?;
              final stateStr = alarmData['state'] as String?;
              
              final id = parseAlarmKitUUID(idStr);
              if (id != null && stateStr != null) {
                final state = _parseState(stateStr);
                if (state == AlarmNativeState.firing) {
                  _routeNativeEvent(id, state, AlarmInteractionType.none);
                }
              }
            }
          }
        }
      }
    }
  }

  /// Reconciles local DB state against the native platform state.
  /// Applies rules for recovering interrupted missions or canceling stale ones.
  Future<void> _reconcile(List<PlatformAlarmState> nativeAlarms) async {
    final alarms = await getAlarms();
    final now = DateTime.now();
    
    final nativeIds = nativeAlarms.map((na) => na.alarmId).toSet();
    final activeSessionId = await WakeSessionController.instance.getDurableActiveSessionId();

    // Whether any native alarm belonging to [originalId]'s family (the
    // real alarm itself, its reactive Wake Check slot, or any pre-scheduled
    // chain descendant) is CURRENTLY firing/alerting, per the platform's
    // own live state — not Dart's persisted bookkeeping. This matters
    // because activeSessionId is only ever set by WakeSessionController
    // actually running in-process; if the app was killed before the alarm
    // ever fired (the exact scenario the Wake Check chain exists for),
    // nothing ever set it, so activeSessionId alone can never recognize a
    // still-ringing alarm on cold start. Confirmed live: a killed app,
    // reopened while its chain kept relentlessly ringing, showed a normal
    // alarm list instead of recovering into the mission screen.
    bool isFiringForOriginal(int originalId) {
      return nativeAlarms.any((na) {
        if (na.nativeState != 'firing') return false;
        if (na.alarmId == originalId) return true;
        if (na.alarmId == wakeCheckAlarmIdFor(originalId)) return true;
        if (isWakeCheckChainAlarmId(na.alarmId) && chainOriginalAlarmId(na.alarmId) == originalId) return true;
        return false;
      });
    }

    for (final alarm in alarms) {
      final isInNative = nativeIds.contains(alarm.id);

      // Recovery takes priority over EVERYTHING below, including whether
      // the alarm is currently marked enabled — checked first,
      // unconditionally, before the enabled-gate that used to sit ahead of
      // it. A stale `enabled: false` written by an earlier reconcile bug
      // (this exact class of bug has bitten this alarm before tonight) must
      // never be able to permanently block recovering a session that is,
      // right now, genuinely still firing on the native side — a
      // disabled-but-firing alarm is a contradiction that can only mean our
      // own bookkeeping is out of sync with reality, and reality (the
      // native platform's own live state) wins. Also covers the
      // RECURRING-alarm case: nextOccurrence() always resolves to a future
      // date once any time has passed today — always true while ringing —
      // so the stale/future classification further below would never
      // recognize a recurring alarm as needing recovery on its own; it
      // would see "next occurrence is tomorrow" and silently advance it.
      // Confirmed live, repeatedly: a killed app reopened while its Wake
      // Check chain kept relentlessly ringing showed the normal alarm list
      // instead of recovering into the mission screen.
      if (activeSessionId == alarm.id || isFiringForOriginal(alarm.id)) {
        debugPrint('Reconcile: Alarm ${alarm.id} was the active session or is currently firing natively. Recovering WakeSession.');
        if (!alarm.enabled) {
          await _repository.save(alarm.copyWith(enabled: true, updatedAt: now));
        }
        _routeNativeEvent(alarm.id, AlarmNativeState.firing, AlarmInteractionType.none);
        continue;
      }

      if (!alarm.enabled) {
        // Disabled but exists in native -> Cancel
        if (isInNative) {
          debugPrint('Reconcile: Alarm ${alarm.id} is disabled but scheduled natively. Canceling native.');
          await _scheduler.cancel(alarm.id);
        }
        continue;
      }

      // It is Enabled. Let's check its time relevance.
      DateTime? resolvedTime;
      if (alarm.recurrence.isOneShot) {
        resolvedTime = alarm.time;
      } else {
        // For recurring alarms, the original `time` might be past, but we look at nextOccurrence
        resolvedTime = AlarmScheduler.nextOccurrence(alarm, now);
      }

      if (resolvedTime == null) {
        // A one-shot that is past, or a recurrence that couldn't yield a next time.
        debugPrint('Reconcile: Alarm ${alarm.id} is stale and was not active. Disabling.');
        final updatedAlarm = alarm.copyWith(enabled: false, updatedAt: now);
        await _repository.save(updatedAlarm);
        if (isInNative) await _scheduler.cancel(alarm.id);
      } else if (resolvedTime.isBefore(now) || resolvedTime.isAtSameMomentAs(now)) {
        // Still stale even after resolution (should only happen for one-shot past alarms)
        debugPrint('Reconcile: Alarm ${alarm.id} is stale and was not active. Disabling.');
        final updatedAlarm = alarm.copyWith(enabled: false, updatedAt: now);
        await _repository.save(updatedAlarm);
        if (isInNative) await _scheduler.cancel(alarm.id);
      } else {
        // It's in the future.
        if (!isInNative) {
          // Enabled + future + native missing -> Schedule it
          debugPrint('Reconcile: Alarm ${alarm.id} is enabled for future but missing natively. Rescheduling.');
          final updatedAlarm = alarm.copyWith(time: resolvedTime, updatedAt: now);
          await _scheduler.schedule(updatedAlarm);
          if (resolvedTime != alarm.time) {
             await _repository.save(updatedAlarm);
          }
        } else {
          // Enabled + future + native exists -> Keep
          // But update the local time if it's a recurring alarm whose base time is past
          if (resolvedTime != alarm.time) {
            debugPrint('Reconcile: Alarm ${alarm.id} is recurring and base time is past. Advancing to nextOccurrence.');
            final updatedAlarm = alarm.copyWith(time: resolvedTime, updatedAt: now);
            await _scheduler.schedule(updatedAlarm);
            await _repository.save(updatedAlarm);
          }
        }
      }
    }
    
    // Pass 2: Find orphaned native alarms (deleted locally)
    //
    // Wake Check chain alarms (see kWakeCheckChainIdBase) are scheduled
    // directly by native code and deliberately have no Dart-side record —
    // they must NOT be treated as orphaned, or this wipes out the entire
    // hardware-button-dismiss backstop the moment the app is ever
    // reconciled (e.g. on cold start, or when brought to foreground by the
    // alarm's own "Open Wakely" intent) while the chain is still pending.
    final localIds = alarms.map((a) => a.id).toSet();
    for (final nativeAlarm in nativeAlarms) {
      if (!localIds.contains(nativeAlarm.alarmId) && !isWakeCheckChainAlarmId(nativeAlarm.alarmId)) {
        debugPrint('Reconcile: Alarm ${nativeAlarm.alarmId} exists natively but is deleted locally. Canceling native.');
        await _scheduler.cancel(nativeAlarm.alarmId);
      }
    }
  }

  AlarmNativeState _parseState(String stateStr) {
    switch (stateStr) {
      case 'scheduled': return AlarmNativeState.scheduled;
      case 'firing': return AlarmNativeState.firing;
      case 'snoozed': return AlarmNativeState.snoozed;
      case 'completed': return AlarmNativeState.completed;
      case 'stopped': return AlarmNativeState.stopped;
      default: return AlarmNativeState.unknown;
    }
  }

  void _routeNativeEvent(int alarmId, AlarmNativeState state, AlarmInteractionType interaction) {
    // If the user interacted, we assume they stopped the native alarm, so Wakely takes over audio.
    // Otherwise, assume native AlarmKit owns the audio (e.g. standard firing event).
    final ownership = (interaction == AlarmInteractionType.stop || interaction == AlarmInteractionType.openWakely) 
        ? AudioOwnership.wakely 
        : AudioOwnership.nativeAlarmKit;

    final event = AlarmEvent(
      alarmId: alarmId,
      state: state,
      interaction: interaction,
      audioOwnership: ownership,
      timestamp: DateTime.now(),
    );
    WakeSessionController.instance.handleAlarmEvent(event);
  }

  // Deprecated: Stream for main.dart to listen to native interactions
  // Now handled by WakeSessionController
  final _nativeInteractionController = StreamController<AlarmSettings>.broadcast();
  Stream<AlarmSettings> get nativeInteractionStream => _nativeInteractionController.stream;

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
      if (!alarm.enabled) {
        continue;
      }
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

  /// Helper to ensure a new or edited one-shot alarm is in the future.
  DateTime _ensureFutureOneShot(WakelyAlarm alarm, DateTime now) {
    if (alarm.recurrence.isOneShot && (alarm.time.isBefore(now) || alarm.time.isAtSameMomentAs(now))) {
      return DateTime(
        now.year,
        now.month,
        now.day + 1,
        alarm.time.hour,
        alarm.time.minute,
        0,
      );
    }
    return alarm.time;
  }

  /// Create a new alarm.
  ///
  /// Allocates a new ID, schedules it if enabled, and persists it.
  Future<WakelyAlarm> createAlarm(WakelyAlarm alarm) async {
    final newId = await AlarmIdAllocator.allocate();
    return _scheduleAndPersist(alarm.copyWith(id: newId));
  }

  /// Create or replace an alarm using the ID already set on [alarm], bypassing
  /// [AlarmIdAllocator]. Used for alarms whose ID must be deterministic and
  /// known ahead of time (e.g. the Wake Check fallback, which is derived from
  /// its parent alarm's ID so it can be reliably cancelled later).
  Future<WakelyAlarm> createAlarmWithExplicitId(WakelyAlarm alarm) {
    return _scheduleAndPersist(alarm);
  }

  Future<WakelyAlarm> _scheduleAndPersist(WakelyAlarm alarm) async {
    // Enforce future time for creation
    final timeWithFuture = _ensureFutureOneShot(alarm, DateTime.now());
    final alarmWithFuture = alarm.copyWith(time: timeWithFuture);

    final fireTime = AlarmScheduler.calculateFireTime(alarmWithFuture, DateTime.now());
    final finalAlarm = alarmWithFuture.copyWith(time: fireTime);

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

    // 2. Enforce future time for edits
    final timeWithFuture = _ensureFutureOneShot(alarm, DateTime.now());
    final alarmWithFuture = alarm.copyWith(time: timeWithFuture);

    // 3. Calculate new fire time based on updated properties
    final fireTime = AlarmScheduler.calculateFireTime(alarmWithFuture, DateTime.now());
    final finalAlarm = alarmWithFuture.copyWith(time: fireTime, updatedAt: DateTime.now());

    // 4. Schedule if enabled
    if (finalAlarm.enabled) {
      await _scheduler.schedule(finalAlarm);
    }

    // 5. Save to repository
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

  /// Cancel all not-yet-fired alarms in [id]'s pre-scheduled Wake Check
  /// chain (iOS AlarmKit only). Called on mission completion/escape so the
  /// chain doesn't keep ringing after the user has genuinely finished.
  Future<void> cancelWakeCheckChain(int id) async {
    await _scheduler.cancelWakeCheckChain(id);
  }

  /// Pause the back half of [id]'s Wake Check chain while its mission is
  /// actively being solved, keeping a short live tail armed (iOS AlarmKit
  /// only). See WakeSessionController's mission watchdog.
  Future<void> pauseWakeCheckChain(int id) async {
    await _scheduler.pauseWakeCheckChain(id);
  }

  /// Resume the back half [pauseWakeCheckChain] paused.
  Future<void> resumeWakeCheckChain(int id) async {
    await _scheduler.resumeWakeCheckChain(id);
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

    // This ring cycle is over - a future firing gets a fresh snooze budget
    // and, if a ring announcement is configured, speaks again rather than
    // staying silent because of this firing's dedupe window.
    _snoozeCounts.remove(id);
    AlarmAnnouncementService.clearDedupe(id);

    // Always cancel current first to prevent any race conditions or duplicates
    await _scheduler.cancel(id);

    if (alarm.type == AlarmType.quickAlarm) {
      // Quick alarms are ephemeral. Once completed, they are deleted.
      await _repository.delete(id);
    } else if (alarm.recurrence.isOneShot) {
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
      if (alarm.recurrence.isOneShot && alarm.time.isBefore(DateTime.now())) {
        // Recovery of a one-shot alarm that should have fired while device was off.
        // DO NOT silently advance to tomorrow. Disable it.
        final updatedAlarm = alarm.copyWith(enabled: false, updatedAt: DateTime.now());
        await _repository.save(updatedAlarm);
        notifyListeners();
        return;
      }

      // Recalculate fire time in case we missed it while offline
      final fireTime = AlarmScheduler.calculateFireTime(alarm, DateTime.now());
      final updatedAlarm = alarm.copyWith(time: fireTime, updatedAt: DateTime.now());
      
      await _scheduler.schedule(updatedAlarm);
      await _repository.save(updatedAlarm);
    }
  }
}
