import 'package:flutter/services.dart';
import '../domain/alarm_model.dart';
import '../domain/mission_config.dart';
import '../domain/platform_alarm_state.dart';
import 'platform_alarm_scheduler.dart';
import 'alarm_kit_uuid.dart';
import '../../sounds/data/sound_repository.dart';

/// AlarmKit implementation for iOS 26+ devices.
class AlarmKitIOSAlarmScheduler implements PlatformAlarmScheduler {
  static const MethodChannel _channel = MethodChannel('wakely.alarmkit');

  @override
  Future<void> schedule(WakelyAlarm alarm, DateTime fireTime) async {
    final nativeSound = SoundRepository.instance.getNativeIOSSoundFilename(alarm.soundId);

    // Must key off whether a mission is actually configured
    // (mission.type != none), not alarm.type != AlarmType.standard — a
    // mission can be attached to any alarm type, standard included (see
    // the matching fix and full explanation in
    // WakeSessionController.handleAlarmEvent). No-mission alarms never
    // need a Wake Check.
    //
    // Wake Check alarms themselves (id >= kWakeCheckIdOffset) are
    // DELIBERATELY NOT excluded here: re-alerting must actually repeat
    // (relentlessly, not just once) if the user keeps silencing it without
    // completing the mission — a single follow-up reads as a snooze, which
    // is a different feature. The native side bounds the cascade itself
    // with its own cycle counter (see scheduleWakeCheckIfNeeded in
    // AlarmKitManager.swift), mirroring kMaxWakeCheckReAlerts here, so this
    // can't spiral into literal unbounded spam.
    final requiresWakeCheck = alarm.mission.type != MissionType.none;

    await _channel.invokeMethod('scheduleAlarm', {
      'id': alarm.id.toString(),
      'fireTime': fireTime.millisecondsSinceEpoch,
      'soundName': nativeSound,
      'requiresWakeCheck': requiresWakeCheck,
    });
  }

  @override
  Future<void> cancel(int alarmId) async {
    try {
      await _channel.invokeMethod('cancelAlarm', {
        'id': alarmId.toString(),
      });
    } on PlatformException catch (e) {
      // If the alarm is already deleted or not found natively, it throws an error.
      // We can safely ignore this because the goal of cancel is achieved (alarm is gone).
    }
  }

  @override
  Future<void> cancelWakeCheckChain(int alarmId) async {
    try {
      await _channel.invokeMethod('cancelWakeCheckChain', {
        'id': alarmId.toString(),
      });
    } on PlatformException catch (e) {
      // Best-effort cleanup — if the chain is already gone/never existed,
      // the goal (nothing left to cancel) is already achieved.
    }
  }

  @override
  Future<void> pauseWakeCheckChain(int alarmId) async {
    try {
      await _channel.invokeMethod('pauseWakeCheckChain', {
        'id': alarmId.toString(),
      });
    } on PlatformException catch (e) {
      // Best-effort — worst case the chain stays fully armed, which is safe.
    }
  }

  @override
  Future<void> resumeWakeCheckChain(int alarmId) async {
    try {
      await _channel.invokeMethod('resumeWakeCheckChain', {
        'id': alarmId.toString(),
      });
    } on PlatformException catch (e) {
      // Best-effort.
    }
  }

  @override
  Future<List<PlatformAlarmState>> getScheduledAlarms() async {
    final List<dynamic> alarms = await _channel.invokeMethod('getScheduledAlarms');
    
    return alarms.map((data) {
      final map = data as Map<dynamic, dynamic>;
      return PlatformAlarmState(
        // `id` here is the native UUID string, not a plain integer — it must
        // be decoded with parseAlarmKitUUID, mirroring getUUID(for:) on the
        // Swift side, not parsed directly.
        alarmId: parseAlarmKitUUID(map['id'] as String?) ?? -1,
        nativeState: map['state'] as String ?? 'unknown',
        scheduledAt: map['scheduledAt'] != null 
            ? DateTime.fromMillisecondsSinceEpoch(map['scheduledAt'] as int)
            : null,
      );
    }).toList();
  }

  @override
  Future<bool> isScheduled(int alarmId) async {
    final alarms = await getScheduledAlarms();
    return alarms.any((a) => a.alarmId == alarmId);
  }
}
