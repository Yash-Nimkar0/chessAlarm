import 'package:flutter_test/flutter_test.dart';
import 'package:wakely/features/alarms/domain/alarm_event.dart';
import 'package:wakely/features/alarms/domain/alarm_model.dart';
import 'package:wakely/features/alarms/domain/mission_config.dart';
import 'package:wakely/features/alarms/domain/recurrence.dart';
import 'package:wakely/features/alarms/data/alarm_repository.dart';
import 'package:wakely/features/alarms/application/wake_session_controller.dart';
import 'package:wakely/features/alarms/application/wake_audio_session_controller.dart';
import '../../../test_helpers/alarm_test_env.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('War Room Pipeline Tests', () {
    setUp(() async {
      await setUpAlarmTestEnvironment();
    });

    tearDown(() async {
      await WakeSessionController.instance.stopSession();
    });

    test('Canonical Event Pipeline routes correctly and is idempotent', () async {
      // Create a mock alarm
      final testAlarm = WakelyAlarm(
        id: 1,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.standard,
        soundId: 'wakely_celestial',
        mission: MissionConfig(type: MissionType.typing),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // We need to inject it directly into the repository for the controller to find it
      await AlarmRepository().save(testAlarm);

      // Simulate native firing event
      final firingEvent = AlarmEvent(
        alarmId: 1,
        state: AlarmNativeState.firing,
        interaction: AlarmInteractionType.none,
        audioOwnership: AudioOwnership.nativeAlarmKit,
        timestamp: DateTime.now(),
      );

      // Act
      await WakeSessionController.instance.handleAlarmEvent(firingEvent);

      // Assert
      expect(WakeSessionController.instance.isActive, isTrue);
      expect(WakeSessionController.instance.activeAlarm?.id, equals(1));
      
      // Audio should NOT be playing because the event was purely 'firing' (AlarmKit owns audio)
      expect(WakeAudioSessionController.instance.isActive, isFalse);

      // Simulate duplicate firing event (idempotency check)
      await WakeSessionController.instance.handleAlarmEvent(firingEvent);
      expect(WakeSessionController.instance.isActive, isTrue); // Should not crash or restart

      // Simulate user interacting with native notification (OpenWakelyIntent)
      final interactionEvent = AlarmEvent(
        alarmId: 1,
        state: AlarmNativeState.unknown,
        interaction: AlarmInteractionType.openWakely,
        audioOwnership: AudioOwnership.wakely,
        timestamp: DateTime.now(),
      );

      await WakeSessionController.instance.handleAlarmEvent(interactionEvent);
      
      // Now audio SHOULD be playing because WakeSession took over from native
      expect(WakeSessionController.instance.currentAudioOwnership, equals(AudioOwnership.wakely));
      
      // Simulate duplicate firing event (after Wakely took ownership)
      await WakeSessionController.instance.handleAlarmEvent(firingEvent);
      // Invariant: Ownership MUST NOT downgrade back to nativeAlarmKit
      expect(WakeSessionController.instance.currentAudioOwnership, equals(AudioOwnership.wakely));
      
      // Simulate native Stop (Standard Alarm)
      final stopEvent = AlarmEvent(
        alarmId: 1,
        state: AlarmNativeState.stopped,
        interaction: AlarmInteractionType.stop,
        audioOwnership: AudioOwnership.nativeAlarmKit,
        timestamp: DateTime.now(),
      );
      
      await WakeSessionController.instance.handleAlarmEvent(stopEvent);
      // Because it's a standard alarm, stopping completes the session
      expect(WakeSessionController.instance.isActive, isFalse);
    });

    test('Mission Alarm native stop transitions to awaitingWakeCheck', () async {
      final missionAlarm = WakelyAlarm(
        id: 3,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.wakeRoutine,
        soundId: 'wakely_celestial',
        mission: MissionConfig(type: MissionType.math),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AlarmRepository().save(missionAlarm);
      
      await WakeSessionController.instance.startSession(3, startAudio: false);
      expect(WakeSessionController.instance.isActive, isTrue);
      
      final stopEvent = AlarmEvent(
        alarmId: 3,
        state: AlarmNativeState.stopped,
        interaction: AlarmInteractionType.stop,
        audioOwnership: AudioOwnership.nativeAlarmKit,
        timestamp: DateTime.now(),
      );
      
      await WakeSessionController.instance.handleAlarmEvent(stopEvent);
      
      // Mission alarm -> native stop -> session still active but awaiting wake check
      expect(WakeSessionController.instance.isActive, isTrue);
      expect(WakeSessionController.instance.sessionState, equals(WakeSessionState.awaitingWakeCheck));
    });

    test('Wake Check fallback alarm is actually cancelled on mission completion', () async {
      final missionAlarm = WakelyAlarm(
        id: 7,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.wakeRoutine,
        soundId: 'wakely_celestial',
        mission: MissionConfig(type: MissionType.math),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AlarmRepository().save(missionAlarm);

      await WakeSessionController.instance.startSession(7, startAudio: false);

      final stopEvent = AlarmEvent(
        alarmId: 7,
        state: AlarmNativeState.stopped,
        interaction: AlarmInteractionType.stop,
        audioOwnership: AudioOwnership.nativeAlarmKit,
        timestamp: DateTime.now(),
      );
      await WakeSessionController.instance.handleAlarmEvent(stopEvent);
      expect(WakeSessionController.instance.sessionState, equals(WakeSessionState.awaitingWakeCheck));

      // The fallback alarm must actually exist with the deterministic ID —
      // this is the ID completeSession()/emergencyEscape() will try to cancel.
      final wakeCheckId = WakeSessionController.wakeCheckAlarmId(7);
      final scheduledFallback = await AlarmRepository().getById(wakeCheckId);
      expect(scheduledFallback, isNotNull,
          reason: 'Wake Check fallback must be persisted under the deterministic ID so it can be cancelled later.');

      // Simulate the user opening Wakely and completing the mission before the
      // fallback fires.
      await WakeSessionController.instance.startSession(7, startAudio: false);
      await WakeSessionController.instance.completeSession();

      // Regression: the fallback alarm must be gone, not silently orphaned.
      final leftoverFallback = await AlarmRepository().getById(wakeCheckId);
      expect(leftoverFallback, isNull,
          reason: 'Wake Check fallback must be cancelled on mission completion, not left to fire as a phantom alarm.');
    });

    test('Synthetic Wakely Firing event directly starts audio', () async {
      final testAlarm = WakelyAlarm(
        id: 2,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.standard,
        soundId: 'wakely_celestial',
        mission: MissionConfig(type: MissionType.typing),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      await AlarmRepository().save(testAlarm);

      // Simulate developer harness Mode B event
      final syntheticEvent = AlarmEvent(
        alarmId: 2,
        state: AlarmNativeState.firing,
        interaction: AlarmInteractionType.none,
        audioOwnership: AudioOwnership.wakely,
        timestamp: DateTime.now(),
      );

      await WakeSessionController.instance.handleAlarmEvent(syntheticEvent);

      expect(WakeSessionController.instance.isActive, isTrue);
      expect(WakeSessionController.instance.currentAudioOwnership, equals(AudioOwnership.wakely));
    });
  });
}
