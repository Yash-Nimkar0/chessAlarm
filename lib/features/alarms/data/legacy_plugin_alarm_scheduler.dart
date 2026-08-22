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
    // AlarmController._reconcile() has a dedicated recovery path
    // (isFiringForOriginal) that exists specifically to recognize a
    // currently-ringing alarm on cold start and route back into the
    // mission screen instead of treating it as a stale/past one-shot alarm
    // and disabling+cancelling it - but that path only works if a native
    // alarm's actual ring state is reported here. Hardcoding 'scheduled'
    // for every alarm regardless of whether it's really ringing defeated
    // that recovery path entirely on this platform: confirmed live, a
    // one-shot alarm that survived a Recents task-removal (thanks to
    // androidStopAlarmOnTermination: false) got silently disabled and
    // stopped anyway the moment the app was reopened, because reconcile's
    // stale-one-shot-alarm check never saw it as still firing.
    return Future.wait(alarms.map((a) async {
      final isRinging = await Alarm.isRinging(a.id);
      return PlatformAlarmState(
        alarmId: a.id,
        nativeState: isRinging ? 'firing' : 'scheduled',
        scheduledAt: a.dateTime,
      );
    }));
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
      // Defaults to true in the `alarm` plugin. Left at the default, the
      // plugin's own AlarmService.onTaskRemoved() fully stops the alarm the
      // instant the app is swiped away from Android's Recents screen - with
      // no re-alert and no mission check. Since a wake-routine alarm's whole
      // point is that a mission must be solved to silence it, that default
      // is a complete one-gesture bypass of mission enforcement on Android.
      androidStopAlarmOnTermination: false,
      // Defaults to false in the `alarm` plugin. Left at the default, if a
      // second alarm's fire time arrives while an earlier one is still
      // actively ringing, AlarmService silently drops the new one entirely
      // (unsaveAlarm + no notification, no ring, just a debug log) instead
      // of queuing or overlapping it - the exact "alarm just didn't fire"
      // failure this app's whole premise is meant to prevent, and a
      // completely ordinary scenario for anyone who sets a backup alarm a
      // few minutes after their primary one.
      allowAlarmOverlap: true,
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
      // This is a separate payload builder from WakelyAlarm.toAlarmSettings()
      // (used by the AlarmKit iOS path) - missionChain/announcementMode/
      // announce* were added there but never mirrored here, so on Android
      // every alarm silently lost its mission chain (beyond the first
      // mission) and its ring announcement always evaluated to 'off'
      // regardless of what the user configured.
      'missionChain': alarm.missionChain.map((m) => m.toJson()).toList(),
      'announcementMode': alarm.announcementMode.toStringValue(),
      'announceDay': alarm.announceDay,
      'announceDate': alarm.announceDate,
      'announceTime': alarm.announceTime,
      'announceWeather': alarm.announceWeather,
    };
    return jsonEncode(payload);
  }
}
