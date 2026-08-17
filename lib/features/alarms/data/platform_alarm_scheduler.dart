import '../domain/alarm_model.dart';
import '../domain/platform_alarm_state.dart';

/// The abstract interface for platform-specific alarm schedulers.
abstract class PlatformAlarmScheduler {
  /// Schedule an alarm natively.
  Future<void> schedule(WakelyAlarm alarm, DateTime fireTime);
  
  /// Cancel an alarm natively.
  Future<void> cancel(int alarmId);
  
  /// Get all currently scheduled alarms.
  Future<List<PlatformAlarmState>> getScheduledAlarms();
  
  /// Check if a specific alarm is scheduled.
  Future<bool> isScheduled(int alarmId);
}
