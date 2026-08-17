import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

/// Flutter interface for the native iOS 26+ AlarmKit.
/// 
/// This is used exclusively as a spike to test native reliability.
class WakelyAlarmKitPlugin {
  static const MethodChannel _channel = MethodChannel('com.yashnimkar.chessAlarm/alarmkit');
  
  static final WakelyAlarmKitPlugin instance = WakelyAlarmKitPlugin._();
  
  // Callback when a native AlarmKit alarm is stopped by the user.
  Function(String alarmId)? onAlarmStopped;

  WakelyAlarmKitPlugin._() {
    _channel.setMethodCallHandler(_handleMethodCall);
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onAlarmStopped') {
      final String alarmId = call.arguments as String;
      if (onAlarmStopped != null) {
        onAlarmStopped!(alarmId);
      }
    }
  }

  /// Schedules an AlarmKit alarm.
  /// 
  /// The [timestamp] is milliseconds since epoch.
  /// [soundName] should be the base name of a bundled asset.
  Future<bool> scheduleAlarm({
    required String id,
    required DateTime time,
    required String soundName,
  }) async {
    try {
      final result = await _channel.invokeMethod('scheduleAlarm', {
        'id': id,
        'timestamp': time.millisecondsSinceEpoch.toDouble(),
        'soundName': soundName,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint("AlarmKit schedule error: ${e.message}");
      return false;
    }
  }

  /// Cancels an existing AlarmKit alarm.
  Future<bool> cancelAlarm(String id) async {
    try {
      final result = await _channel.invokeMethod('cancelAlarm', {
        'id': id,
      });
      return result == true;
    } on PlatformException catch (e) {
      debugPrint("AlarmKit cancel error: ${e.message}");
      return false;
    }
  }
}
