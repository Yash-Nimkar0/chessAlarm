/// Represents the active state of an alarm on the native platform.
class PlatformAlarmState {
  /// The Wakely domain alarm ID.
  final int alarmId;
  
  /// The native state representation (e.g. "scheduled", "firing", "snoozed", "stopped").
  final String nativeState;
  
  /// The time the alarm is scheduled to fire, according to the platform.
  final DateTime? scheduledAt;

  const PlatformAlarmState({
    required this.alarmId,
    required this.nativeState,
    this.scheduledAt,
  });
}
