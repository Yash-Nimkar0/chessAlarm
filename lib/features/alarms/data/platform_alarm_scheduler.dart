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

  /// Cancels all not-yet-fired alarms in a pre-scheduled Wake Check chain
  /// belonging to [alarmId] (see AlarmKitIOSAlarmScheduler). No-op by
  /// default — only iOS AlarmKit pre-schedules a chain that needs this;
  /// other platforms have nothing to cancel here.
  Future<void> cancelWakeCheckChain(int alarmId) async {}

  /// Cancels the "back half" of [alarmId]'s pre-scheduled Wake Check chain
  /// while the mission is actively, genuinely being solved, keeping a
  /// short live tail armed. No-op by default — see cancelWakeCheckChain.
  Future<void> pauseWakeCheckChain(int alarmId) async {}

  /// Reschedules the back half [pauseWakeCheckChain] cancelled, starting
  /// fresh from now. No-op by default — see cancelWakeCheckChain.
  Future<void> resumeWakeCheckChain(int alarmId) async {}
}
