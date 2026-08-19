import 'dart:convert';
import 'package:alarm/alarm.dart';
import '../domain/alarm_model.dart';
import '../domain/platform_alarm_state.dart';
import 'platform_alarm_scheduler.dart';
import '../../sounds/data/sound_repository.dart';

/// Legacy scheduler implementation that delegates to the `alarm` plugin.
/// This handles Android and iOS versions < 26.
class LegacyPluginAlarmScheduler implements PlatformAlarmScheduler {
  @override
  Future<void> schedule(WakelyAlarm alarm, DateTime fireTime) async {
    final settings = _toPlatformSettings(alarm, fireTime);
    await Alarm.set(alarmSettings: settings);
  }

  @override
  Future<void> cancel(int alarmId) async {
    await Alarm.stop(alarmId);
  }

  @override
  Future<List<PlatformAlarmState>> getScheduledAlarms() async {
    final alarms = await Alarm.getAlarms();
    return alarms.map((a) => PlatformAlarmState(
      alarmId: a.id,
      nativeState: 'scheduled',
      scheduledAt: a.dateTime,
    )).toList();
  }

  @override
  Future<bool> isScheduled(int alarmId) async {
    final alarms = await Alarm.getAlarms();
    return alarms.any((a) => a.id == alarmId);
  }

  @override
  Future<void> cancelWakeCheckChain(int alarmId) async {}

  @override
  Future<void> pauseWakeCheckChain(int alarmId) async {}

  @override
  Future<void> resumeWakeCheckChain(int alarmId) async {}

  /// Convert a [WakelyAlarm] to the platform [AlarmSettings].
  AlarmSettings _toPlatformSettings(WakelyAlarm alarm, DateTime fireTime) {
    final sound = SoundRepository.instance.getSoundById(alarm.soundId);
    final platformAssetPath = sound?.path ?? 'assets/audio/alarms/marmixer-soft-morning-484625.mp3';

    return AlarmSettings(
      id: alarm.id,
      dateTime: fireTime,
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
      // Preserve backward compatibility
      payload: _buildLegacyPayload(alarm),
    );
  }

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
