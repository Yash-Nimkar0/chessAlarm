import 'package:flutter/services.dart';
import '../domain/alarm_model.dart';
import '../domain/platform_alarm_state.dart';
import 'platform_alarm_scheduler.dart';
import '../../sounds/data/sound_repository.dart';

/// AlarmKit implementation for iOS 26+ devices.
class AlarmKitIOSAlarmScheduler implements PlatformAlarmScheduler {
  static const MethodChannel _channel = MethodChannel('wakely.alarmkit');

  @override
  Future<void> schedule(WakelyAlarm alarm, DateTime fireTime) async {
    final nativeSound = SoundRepository.instance.getNativeIOSSoundFilename(alarm.soundId);

    await _channel.invokeMethod('scheduleAlarm', {
      'id': alarm.id.toString(),
      'fireTime': fireTime.millisecondsSinceEpoch,
      'soundName': nativeSound,
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
  Future<List<PlatformAlarmState>> getScheduledAlarms() async {
    final List<dynamic> alarms = await _channel.invokeMethod('getScheduledAlarms');
    
    return alarms.map((data) {
      final map = data as Map<dynamic, dynamic>;
      return PlatformAlarmState(
        alarmId: int.tryParse(map['id'] as String ?? '') ?? -1,
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
