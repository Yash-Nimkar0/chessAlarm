import 'dart:convert';
import 'package:alarm/alarm.dart';
import '../domain/alarm_model.dart';
import '../../sounds/data/sound_repository.dart';

/// Platform scheduling layer for alarms.
///
/// This class owns all interactions with the `alarm` plugin (Alarm.set,
/// Alarm.stop, Alarm.getAlarms). It also contains the pure recurrence
/// calculation logic, which is independently testable.
///
/// It does NOT own persistence — that's [AlarmRepository]'s job.
class AlarmScheduler {
  /// Schedule a platform alarm for the given [WakelyAlarm].
  ///
  /// Converts the domain model to the platform's [AlarmSettings] and calls
  /// [Alarm.set]. If the alarm is disabled, this is a no-op.
  Future<void> schedule(WakelyAlarm alarm) async {
    if (!alarm.enabled) return;

    final settings = _toPlatformSettings(alarm);
    await Alarm.set(alarmSettings: settings);
  }

  /// Cancel a platform alarm by ID.
  Future<void> cancel(int alarmId) async {
    await Alarm.stop(alarmId);
  }

  /// Get all currently scheduled platform alarms.
  Future<List<AlarmSettings>> getScheduledAlarms() async {
    return await Alarm.getAlarms();
  }

  /// Check if a specific alarm ID is currently scheduled on the platform.
  Future<bool> isScheduled(int alarmId) async {
    final alarms = await getScheduledAlarms();
    return alarms.any((a) => a.id == alarmId);
  }

  // ---------------------------------------------------------------------------
  // Recurrence calculation (pure logic, independently testable)
  // ---------------------------------------------------------------------------

  /// Calculate the next fire time for a recurring alarm.
  ///
  /// For recurring alarms: finds the next valid day on or after [now],
  /// preserving the alarm's time-of-day.
  ///
  /// For one-shot alarms: returns null (one-shot alarms should not be
  /// rescheduled — they fire once and are done).
  ///
  /// The [afterFiring] parameter should be true when rescheduling after an
  /// alarm has just fired. In that case, we always advance to the next valid
  /// day (never the same day, since the alarm just fired today).
  static DateTime? nextOccurrence(WakelyAlarm alarm, DateTime now, {bool afterFiring = false}) {
    if (alarm.recurrence.isOneShot) return null;

    // Start from the alarm's time-of-day applied to today.
    DateTime candidate = DateTime(
      now.year,
      now.month,
      now.day,
      alarm.time.hour,
      alarm.time.minute,
      0,
    );

    // If rescheduling after firing, always advance past today.
    if (afterFiring) {
      candidate = candidate.add(const Duration(days: 1));
    } else if (candidate.isBefore(now) || candidate.isAtSameMomentAs(now)) {
      // If the candidate time has already passed today, start from tomorrow.
      candidate = candidate.add(const Duration(days: 1));
    }

    // Search forward up to 7 days for the next active day.
    for (int i = 0; i < 7; i++) {
      final dayIndex = candidate.weekday - 1; // weekday: 1=Mon → index 0
      if (alarm.recurrence.days[dayIndex]) {
        return candidate;
      }
      candidate = candidate.add(const Duration(days: 1));
    }

    // Should never reach here if recurrence has at least one day selected.
    return null;
  }

  /// Calculate the appropriate fire time for a new or edited alarm.
  ///
  /// For one-shot alarms: if the selected time is in the past, returns
  /// the same time tomorrow (UI should have already warned the user).
  ///
  /// For recurring alarms: delegates to [nextOccurrence].
  static DateTime calculateFireTime(WakelyAlarm alarm, DateTime now) {
    if (alarm.recurrence.isOneShot) {
      // One-shot: if past, advance to tomorrow.
      if (alarm.time.isBefore(now) || alarm.time.isAtSameMomentAs(now)) {
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

    // Recurring: find next valid occurrence.
    return nextOccurrence(alarm, now) ?? alarm.time;
  }

  // ---------------------------------------------------------------------------
  // Platform conversion
  // ---------------------------------------------------------------------------

  /// Convert a [WakelyAlarm] to the platform [AlarmSettings].
  AlarmSettings _toPlatformSettings(WakelyAlarm alarm) {
    final sound = SoundRepository.instance.getSoundById(alarm.soundId);
    final platformAssetPath = sound?.path ?? 'assets/audio/alarms/marmixer-soft-morning-484625.mp3';

    return AlarmSettings(
      id: alarm.id,
      dateTime: alarm.time,
      assetAudioPath: platformAssetPath,
      loopAudio: alarm.loopAudio,
      vibrate: alarm.vibrate,
      volumeSettings: alarm.fadeIn && alarm.fadeDuration > 0
          ? VolumeSettings.fade(
              volume: alarm.volume,
              fadeDuration: Duration(seconds: alarm.fadeDuration),
            )
          : VolumeSettings.fixed(
              volume: alarm.volume,
            ),
      notificationSettings: NotificationSettings(
        title: alarm.label ?? (alarm.type == AlarmType.wakeRoutine ? 'Wake Routine' : 'Alarm'),
        body: alarm.type == AlarmType.wakeRoutine
            ? 'Time to wake up and solve your challenge.'
            : 'Your alarm is ringing.',
      ),
      // Preserve backward compatibility: store mission + alarm type as payload
      // so the ringing screen can read it (during transition period).
      payload: _buildLegacyPayload(alarm),
    );
  }

  /// Build a legacy-compatible payload string for the platform alarm.
  ///
  /// During the transition period, ringing_screen.dart still reads
  /// MissionSettings from the payload. This generates a compatible JSON string.
  String _buildLegacyPayload(WakelyAlarm alarm) {
    final Map<String, dynamic> payload = {
      'type': alarm.type.toStringValue(),
      'version': 1,
      'sleepGoal': alarm.sleepGoal,
      'mission': alarm.mission.type.toStringValue(),
      'sleepTracking': alarm.sleepTracking,
      'sleepSounds': alarm.sleepSounds,
      'createdAt': alarm.createdAt.toIso8601String(),
      'difficultyMode': alarm.mission.difficultyMode,
      'smartLock': alarm.smartLock,
      'difficultyOverride': alarm.mission.difficultyOverride,
      'missionRounds': alarm.mission.rounds,
      'missionData': alarm.mission.data,
      'label': alarm.label,
    };
    return jsonEncode(payload);
  }
}
