import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:alarm/alarm.dart';
import 'package:wakely/features/alarms/application/wake_session_controller.dart';
import 'package:wakely/features/alarms/application/wake_audio_session_controller.dart';
import 'package:wakely/features/alarms/application/alarm_controller.dart';
import 'package:wakely/features/alarms/data/alarm_repository.dart';
import 'package:wakely/features/alarms/domain/alarm_model.dart';
import 'package:wakely/features/alarms/domain/mission_config.dart';
import 'package:wakely/features/alarms/domain/recurrence.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('WakeSessionController Tests', () {
    setUp(() async {
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
    });

    tearDown(() async {
      await WakeSessionController.instance.stopSession();
    });

    test('startSession is idempotent', () async {
      final controller = WakeSessionController.instance;

      // Attempt to start a session for a non-existent alarm
      await controller.startSession(999);
      expect(controller.isActive, isFalse);
    });

    test('completeSession is a silent no-op if the session was never started (regression)', () async {
      // This is exactly what used to happen on the Android/legacy
      // (SlideToStopScreen -> RingingScreen) path before it called
      // startSession(): RingingScreen would call completeSession() on
      // mission success, but WakeSessionController never knew a session
      // was active, so completeAlarm() was silently never invoked —
      // recurring alarms never rescheduled and one-shot alarms never
      // cleanly disabled.
      final alarm = WakelyAlarm(
        id: 501,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.wakeRoutine,
        mission: MissionConfig(type: MissionType.typing),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AlarmRepository().save(alarm);

      // No startSession() call here — this reproduces the bug.
      await WakeSessionController.instance.completeSession();

      final stillEnabled = await AlarmRepository().getById(501);
      expect(stillEnabled?.enabled, isTrue,
          reason: 'Documents the bug: without a prior startSession(), completeSession() must not touch the alarm.');
    });

    test('SlideToStopScreen fix: startSession() before completeSession() correctly completes the alarm', () async {
      final alarm = WakelyAlarm(
        id: 502,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.wakeRoutine,
        mission: MissionConfig(type: MissionType.typing),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AlarmRepository().save(alarm);

      // Mirrors what slide_to_stop_screen.dart now does before navigating
      // to RingingScreen for a mission alarm.
      await WakeSessionController.instance.startSession(502, startAudio: false);
      expect(WakeSessionController.instance.isActive, isTrue);

      await WakeSessionController.instance.completeSession();

      final completed = await AlarmRepository().getById(502);
      expect(completed?.enabled, isFalse,
          reason: 'A one-shot alarm must be disabled once completeSession() actually runs completeAlarm().');
    });
  });
}
