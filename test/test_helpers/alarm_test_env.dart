import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:alarm/alarm.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakle/features/alarms/application/alarm_controller.dart';
import 'package:wakle/features/alarms/application/wake_audio_session_controller.dart';

/// Sets up the full mock platform-channel environment required for any test
/// that touches AlarmController.instance.init() / AlarmScheduler.init() /
/// the `alarm` plugin, and then runs AlarmController.instance.init().
///
/// Without every one of these mocks, AlarmController.instance.init() hangs
/// indefinitely (Alarm.init() sets up the `alarm` plugin's isolate-based
/// communication; skipping it leaves that isolate port waiting forever) —
/// the resulting failure mode is a 30s test timeout with a
/// `_RawReceivePort._handleMessage` stack, not a clear error, so it's easy
/// to lose time to. Always call this from setUp() rather than assembling
/// the mocks by hand.
Future<void> setUpAlarmTestEnvironment() async {
  SharedPreferences.setMockInitialValues({});

  const MethodChannel('xyz.luan/audioplayers.global').setMockMethodCallHandler((MethodCall methodCall) async {
    return 1;
  });
  const MethodChannel('xyz.luan/audioplayers').setMockMethodCallHandler((MethodCall methodCall) async {
    return 1;
  });
  const MethodChannel('com.kurenai7968.volume_controller.method').setMockMethodCallHandler((MethodCall methodCall) async {
    return 0.5;
  });
  const MethodChannel('plugins.flutter.io/path_provider').setMockMethodCallHandler((MethodCall methodCall) async {
    return '/tmp';
  });
  const MethodChannel('wakely.alarmkit').setMockMethodCallHandler((MethodCall methodCall) async {
    return null;
  });

  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.alarm.AlarmApi.setAlarm',
    (ByteData? message) async => const StandardMessageCodec().encodeMessage([null]),
  );
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger.setMockMessageHandler(
    'dev.flutter.pigeon.alarm.AlarmApi.stopAlarm',
    (ByteData? message) async => const StandardMessageCodec().encodeMessage([null]),
  );

  await Alarm.init();
  WakeAudioSessionController.instance.isTestMode = true;

  try {
    await AlarmController.instance.init();
  } catch (_) {}
}
