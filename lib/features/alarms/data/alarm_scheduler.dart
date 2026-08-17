import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import '../domain/alarm_model.dart';
import '../domain/alarm_kit_capability.dart';
import '../domain/platform_alarm_state.dart';
import 'platform_alarm_scheduler.dart';
import 'legacy_plugin_alarm_scheduler.dart';
import 'alarm_kit_ios_alarm_scheduler.dart';

/// Platform scheduling layer for alarms.
///
/// This class acts as a router. It delegates actual scheduling to the
/// appropriate [PlatformAlarmScheduler] (Android, Legacy iOS, or AlarmKit iOS).
/// It also contains the pure recurrence calculation logic.
class AlarmScheduler {
  PlatformAlarmScheduler? _platformScheduler;
  Future<void>? _initFuture;

  /// Initialize the correct platform scheduler based on OS capabilities.
  /// This ensures exactly one initialization.
  Future<void> init() {
    return _initFuture ??= _initialize().catchError((error) {
      // Allow retry if initialization fails instead of being permanently broken
      _initFuture = null;
      throw error;
    });
  }

  Future<void> _initialize() async {
    final isIOS = kIsWeb ? false : defaultTargetPlatform == TargetPlatform.iOS;
    if (isIOS) {
      final capability = await checkAlarmKitCapability();
      if (capability.supported && 
          (capability.authorization == AlarmKitAuthorization.authorized || 
           capability.authorization == AlarmKitAuthorization.notDetermined)) {
        _platformScheduler = AlarmKitIOSAlarmScheduler();
      } else {
        _platformScheduler = LegacyPluginAlarmScheduler();
      }
    } else {
      _platformScheduler = LegacyPluginAlarmScheduler();
    }
  }

  Future<PlatformAlarmScheduler> get _scheduler async {
    await init();
    return _platformScheduler!;
  }

  /// Checks the current AlarmKit capability and authorization status.
  static Future<AlarmKitCapability> checkAlarmKitCapability() async {
    final isIOS = kIsWeb ? false : defaultTargetPlatform == TargetPlatform.iOS;
    if (!isIOS) return AlarmKitCapability.unsupported;
    
    try {
      const channel = MethodChannel('wakely.alarmkit');
      final Map<dynamic, dynamic>? result = await channel.invokeMethod('checkCapability');
      
      if (result == null) return AlarmKitCapability.unsupported;
      
      final supported = result['supported'] as bool? ?? false;
      final authString = result['authorization'] as String? ?? 'unsupported';
      
      AlarmKitAuthorization authorization;
      switch (authString) {
        case 'notDetermined':
          authorization = AlarmKitAuthorization.notDetermined;
          break;
        case 'denied':
          authorization = AlarmKitAuthorization.denied;
          break;
        case 'authorized':
          authorization = AlarmKitAuthorization.authorized;
          break;
        default:
          authorization = AlarmKitAuthorization.unsupported;
      }
      
      return AlarmKitCapability(
        supported: supported,
        authorization: authorization,
      );
    } catch (e) {
      return AlarmKitCapability.unsupported;
    }
  }

  /// Schedule a platform alarm for the given [WakelyAlarm].
  Future<void> schedule(WakelyAlarm alarm) async {
    final scheduler = await _scheduler;
    
    if (!alarm.enabled) {
      await scheduler.cancel(alarm.id);
      return;
    }
    
    final fireTime = calculateFireTime(alarm, DateTime.now());
    await scheduler.schedule(alarm, fireTime);
  }

  /// Cancel a platform alarm by ID.
  Future<void> cancel(int alarmId) async {
    final scheduler = await _scheduler;
    await scheduler.cancel(alarmId);
  }

  /// Get all currently scheduled platform alarms.
  Future<List<PlatformAlarmState>> getScheduledAlarms() async {
    final scheduler = await _scheduler;
    return await scheduler.getScheduledAlarms();
  }

  /// Check if a specific alarm ID is currently scheduled on the platform.
  Future<bool> isScheduled(int alarmId) async {
    final scheduler = await _scheduler;
    return await scheduler.isScheduled(alarmId);
  }

  // ---------------------------------------------------------------------------
  // Recurrence calculation (pure logic, independently testable)
  // ---------------------------------------------------------------------------

  /// Calculate the next fire time for a recurring alarm.
  static DateTime? nextOccurrence(WakelyAlarm alarm, DateTime now, {bool afterFiring = false}) {
    if (alarm.recurrence.isOneShot) return null;

    DateTime candidate = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
      0,
    );

    if (afterFiring) {
      candidate = candidate.add(const Duration(days: 1));
    } else if (candidate.isBefore(now) || candidate.isAtSameMomentAs(now)) {
      candidate = candidate.add(const Duration(days: 1));
    }

    for (int i = 0; i < 7; i++) {
      final dayIndex = candidate.weekday - 1; // weekday: 1=Mon → index 0
      if (alarm.recurrence.days[dayIndex]) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }

    return null;
  }

  /// Calculate the appropriate fire time for an alarm based on intent.
  static DateTime calculateFireTime(WakelyAlarm alarm, DateTime now) {
    if (alarm.recurrence.isOneShot) {
      return alarm.time;
    }
    return nextOccurrence(alarm, now) ?? alarm.time;
  }
}
