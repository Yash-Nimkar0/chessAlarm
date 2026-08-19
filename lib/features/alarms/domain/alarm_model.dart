import 'dart:convert';
import 'package:alarm/alarm.dart';
import 'mission_config.dart';
import 'recurrence.dart';

/// The type of alarm, replacing the old string-based 'type' field in MissionSettings.
enum AlarmType {
  /// Full wake routine: sleep tracking + mission + progression.
  wakeRoutine,

  /// Standard alarm with optional mission.
  standard,

  /// Quick timer for naps/reminders.
  quickAlarm;

  String toStringValue() {
    switch (this) {
      case AlarmType.wakeRoutine:
        return 'wakeRoutine';
      case AlarmType.standard:
        return 'alarm';
      case AlarmType.quickAlarm:
        return 'quickAlarm';
    }
  }

  static AlarmType fromString(String value) {
    switch (value) {
      case 'wakeRoutine':
        return AlarmType.wakeRoutine;
      case 'alarm':
        return AlarmType.standard;
      case 'quickAlarm':
        return AlarmType.quickAlarm;
      // Legacy chess type maps to wake routine
      case 'chess':
        return AlarmType.wakeRoutine;
      default:
        return AlarmType.standard;
    }
  }
}

/// Represents the state of the Wake Check (re-alert enforcement mechanism).
enum WakeCheckState {
  disabled,
  waiting,
  checking,
  confirmed,
  failed,
  reAlertPending
}

/// Represents the logical state of an active wake session.
enum WakeSessionState {
  active,
  missionInProgress,
  awaitingWakeCheck,
  reAlertPending,
  recovering,
  completed,
  emergencyEscaped
}

/// The core alarm domain model.
///
/// This is the single source of truth for an alarm's configuration.
/// It replaces the pattern of spreading alarm data across:
/// - Platform `AlarmSettings` (time, audio, vibrate)
/// - `MissionSettings` payload JSON (mission, type, sleep goal, smart lock)
/// - Separate `alarm_days_<id>` SharedPreferences keys (recurrence)
///
/// All of these are now unified in one model.
class WakelyAlarm {
  final int id;
  final DateTime time;
  final bool enabled;
  final AlarmType type;
  final Recurrence recurrence;
  final String? label;
  final String soundId;
  final bool fadeIn;
  final int fadeDuration;
  final bool loopAudio;
  final bool vibrate;
  final double volume;
  final bool smartLock;
  final MissionConfig mission;
  final double sleepGoal;
  final bool sleepTracking;
  final bool sleepSounds;
  final DateTime createdAt;
  final DateTime updatedAt;

  const WakelyAlarm({
    required this.id,
    required this.time,
    this.enabled = true,
    this.type = AlarmType.standard,
    required this.recurrence,
    this.label,
    this.soundId = 'wakely_soft_morning',
    this.fadeIn = false,
    this.fadeDuration = 30,
    this.loopAudio = true,
    this.vibrate = true,
    this.volume = 0.8,
    this.smartLock = true,
    this.mission = const MissionConfig(),
    this.sleepGoal = 8.0,
    this.sleepTracking = true,
    this.sleepSounds = true,
    required this.createdAt,
    required this.updatedAt,
  });

  WakelyAlarm copyWith({
    int? id,
    DateTime? time,
    bool? enabled,
    AlarmType? type,
    Recurrence? recurrence,
    String? label,
    String? soundId,
    bool? fadeIn,
    int? fadeDuration,
    bool? loopAudio,
    bool? vibrate,
    double? volume,
    bool? smartLock,
    MissionConfig? mission,
    double? sleepGoal,
    bool? sleepTracking,
    bool? sleepSounds,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return WakelyAlarm(
      id: id ?? this.id,
      time: time ?? this.time,
      enabled: enabled ?? this.enabled,
      type: type ?? this.type,
      recurrence: recurrence ?? this.recurrence,
      label: label ?? this.label,
      soundId: soundId ?? this.soundId,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeDuration: fadeDuration ?? this.fadeDuration,
      loopAudio: loopAudio ?? this.loopAudio,
      vibrate: vibrate ?? this.vibrate,
      volume: volume ?? this.volume,
      smartLock: smartLock ?? this.smartLock,
      mission: mission ?? this.mission,
      sleepGoal: sleepGoal ?? this.sleepGoal,
      sleepTracking: sleepTracking ?? this.sleepTracking,
      sleepSounds: sleepSounds ?? this.sleepSounds,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time.toIso8601String(),
      'enabled': enabled,
      'type': type.toStringValue(),
      'recurrence': recurrence.toJson(),
      'label': label,
      'soundId': soundId,
      'fadeIn': fadeIn,
      'fadeDuration': fadeDuration,
      'loopAudio': loopAudio,
      'vibrate': vibrate,
      'volume': volume,
      'smartLock': smartLock,
      'mission': mission.toJson(),
      'sleepGoal': sleepGoal,
      'sleepTracking': sleepTracking,
      'sleepSounds': sleepSounds,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  factory WakelyAlarm.fromJson(Map<String, dynamic> json) {
    return WakelyAlarm(
      id: json['id'] as int,
      time: DateTime.parse(json['time'] as String),
      enabled: json['enabled'] as bool? ?? true,
      type: AlarmType.fromString(json['type'] as String? ?? 'alarm'),
      recurrence: Recurrence.fromJson(json['recurrence'] as Map<String, dynamic>? ?? {'days': List.filled(7, false)}),
      label: json['label'] as String?,
      soundId: json['soundId'] as String? ?? 'wakely_soft_morning',
      fadeIn: json['fadeIn'] as bool? ?? false,
      fadeDuration: json['fadeDuration'] as int? ?? 30,
      loopAudio: json['loopAudio'] as bool? ?? true,
      vibrate: json['vibrate'] as bool? ?? true,
      volume: (json['volume'] as num?)?.toDouble() ?? 0.8,
      smartLock: json['smartLock'] as bool? ?? true,
      mission: MissionConfig.fromJson(json['mission'] as Map<String, dynamic>? ?? {}),
      sleepGoal: (json['sleepGoal'] as num?)?.toDouble() ?? 8.0,
      sleepTracking: json['sleepTracking'] as bool? ?? true,
      sleepSounds: json['sleepSounds'] as bool? ?? true,
      createdAt: DateTime.parse(json['createdAt'] as String? ?? DateTime.now().toIso8601String()),
      updatedAt: DateTime.parse(json['updatedAt'] as String? ?? DateTime.now().toIso8601String()),
    );
  }

  /// Whether this alarm is currently locked (near fire time, editing disabled).
  bool get isLocked {
    if (!smartLock) return false;
    final diff = time.difference(DateTime.now());
    return diff.inMinutes < 2 && time.isAfter(DateTime.now());
  }

  @override
  String toString() => 'WakelyAlarm(id: $id, time: $time, enabled: $enabled, type: $type, label: $label)';

  /// Converts the domain model to a legacy AlarmSettings object.
  /// Used primarily for backward compatibility with RingingScreen and SlideToStopScreen.
  AlarmSettings toAlarmSettings() {
    return AlarmSettings(
      id: id,
      dateTime: time,
      assetAudioPath: soundId,
      loopAudio: loopAudio,
      vibrate: vibrate,
      volumeSettings: fadeIn && fadeDuration > 0
          ? VolumeSettings.fade(
              volume: volume,
              fadeDuration: Duration(seconds: fadeDuration),
            )
          : VolumeSettings.fixed(
              volume: volume,
            ),
      notificationSettings: NotificationSettings(
        title: label ?? (type == AlarmType.wakeRoutine ? 'Wake Routine' : 'Alarm'),
        body: type == AlarmType.wakeRoutine
            ? 'Time to wake up and solve your challenge.'
            : 'Your alarm is ringing.',
      ),
      payload: jsonEncode({
        'type': type.toStringValue(),
        'mission': mission.type.toStringValue(),
        'difficultyMode': mission.difficultyMode,
        'difficultyOverride': mission.difficultyOverride,
        'missionRounds': mission.rounds,
        'missionData': mission.data,
        'label': label,
      }),
    );
  }
}

/// A composite of a WakelyAlarm and its resolved next occurrence.
///
/// Used by UI surfaces to know exactly when the alarm will next ring,
/// avoiding duplicate scheduling calculations and logic errors around
/// alarms whose base `time` is technically in the past.
class ScheduledAlarm {
  final WakelyAlarm alarm;
  final DateTime nextOccurrence;

  const ScheduledAlarm(this.alarm, this.nextOccurrence);

  @override
  String toString() => 'ScheduledAlarm(alarmId: ${alarm.id}, nextOccurrence: $nextOccurrence)';
}
