import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:wakle/features/alarms/domain/alarm_event.dart';
import 'package:wakle/features/alarms/domain/alarm_model.dart';
import 'package:wakle/features/alarms/domain/mission_config.dart';
import 'package:wakle/features/alarms/domain/recurrence.dart';
import 'package:wakle/features/alarms/domain/wake_check_id.dart';
import 'package:wakle/features/alarms/data/alarm_repository.dart';
import 'package:wakle/features/alarms/application/wake_session_controller.dart';
import 'package:wakle/features/alarms/application/wake_audio_session_controller.dart';
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
      
      // Wakely claims the audio session immediately on any firing event
      // (silently — see armForWakeSession) specifically to stay alive in
      // the background from the first ring, even while AlarmKit still
      // natively owns the AUDIBLE sound. isActive now reflects "session
      // claimed" (possibly silent); isAudible is the old "actually making
      // noise" signal this assertion originally meant.
      expect(WakeAudioSessionController.instance.isActive, isTrue);
      expect(WakeAudioSessionController.instance.isAudible, isFalse);

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
      // This alarm has a real mission configured (MissionType.typing) even
      // though it's AlarmType.standard, so native stop must NOT complete
      // it — it must transition to awaitingWakeCheck, exactly like a
      // wakeRoutine mission alarm. This assertion used to be `isFalse`
      // ("because it's a standard alarm, stopping completes the session"),
      // which was asserting the actual production bug: a real device
      // confirmed an alarm with this exact configuration (standard type +
      // configured mission) was fully silenced by native stop with no
      // mission enforced at all.
      expect(WakeSessionController.instance.isActive, isTrue);
      expect(WakeSessionController.instance.sessionState, equals(WakeSessionState.awaitingWakeCheck));
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

    test('CRITICAL: a standard-type alarm with a real mission is NOT silenced by native stop', () async {
      // Confirmed live on a physical device: an alarm rang backgrounded +
      // locked, and native Stop fully silenced it with the mission never
      // enforced at all. Root cause: this gate checked
      // `alarm.type == AlarmType.standard`, but EditAlarmScreen lets a
      // mission be attached to ANY alarm type — "Alarm Mission" is
      // available regardless of whether the alarm is marked Wake Routine.
      // A standard-type alarm with a real mission configured must be
      // treated exactly like a wakeRoutine one: native stop must NOT
      // complete it.
      final standardAlarmWithMission = WakelyAlarm(
        id: 9,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.standard,
        soundId: 'wakely_celestial',
        mission: MissionConfig(type: MissionType.typing),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AlarmRepository().save(standardAlarmWithMission);

      await WakeSessionController.instance.startSession(9, startAudio: false);
      expect(WakeSessionController.instance.isActive, isTrue);

      final stopEvent = AlarmEvent(
        alarmId: 9,
        state: AlarmNativeState.stopped,
        interaction: AlarmInteractionType.stop,
        audioOwnership: AudioOwnership.nativeAlarmKit,
        timestamp: DateTime.now(),
      );
      await WakeSessionController.instance.handleAlarmEvent(stopEvent);

      expect(WakeSessionController.instance.isActive, isTrue,
          reason: 'Native stop must never silently resolve a mission alarm, regardless of its AlarmType.');
      expect(WakeSessionController.instance.sessionState, equals(WakeSessionState.awaitingWakeCheck));

      final alarmAfterStop = await AlarmRepository().getById(9);
      expect(alarmAfterStop?.enabled, isTrue,
          reason: 'The alarm must not be completed/disabled just because native stop was tapped.');
    });

    test('a genuinely no-mission alarm IS completed by native stop', () async {
      // The other half of the same fix: an alarm with no mission at all
      // (mission.type == none) is legitimately fully dismissible via
      // native stop — this must keep working.
      final plainAlarm = WakelyAlarm(
        id: 10,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.standard,
        soundId: 'wakely_celestial',
        mission: const MissionConfig(),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AlarmRepository().save(plainAlarm);

      await WakeSessionController.instance.startSession(10, startAudio: false);
      final stopEvent = AlarmEvent(
        alarmId: 10,
        state: AlarmNativeState.stopped,
        interaction: AlarmInteractionType.stop,
        audioOwnership: AudioOwnership.nativeAlarmKit,
        timestamp: DateTime.now(),
      );
      await WakeSessionController.instance.handleAlarmEvent(stopEvent);

      expect(WakeSessionController.instance.isActive, isFalse);
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

    test('Wake Check re-alerts reuse the same slot and stop after the cycle cap', () async {
      // Requested explicitly to match Alarmy: repeatedly silencing without
      // completing the mission must keep re-alerting (relentlessly, on a
      // short interval, not a multi-minute snooze-like gap), bounded so it
      // can't spiral into literal unbounded spam.
      final alarm = WakelyAlarm(
        id: 20,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.wakeRoutine,
        mission: MissionConfig(type: MissionType.typing),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AlarmRepository().save(alarm);

      final wakeCheckId = wakeCheckAlarmIdFor(20);
      int currentAlarmId = 20;

      for (int cycle = 1; cycle <= kMaxWakeCheckReAlerts + 3; cycle++) {
        await WakeSessionController.instance.startSession(currentAlarmId, startAudio: false);
        await WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
          alarmId: currentAlarmId,
          state: AlarmNativeState.stopped,
          interaction: AlarmInteractionType.stop,
          audioOwnership: AudioOwnership.nativeAlarmKit,
          timestamp: DateTime.now(),
        ));

        final fallback = await AlarmRepository().getById(wakeCheckId);
        if (cycle <= kMaxWakeCheckReAlerts) {
          expect(fallback, isNotNull, reason: 'Cycle $cycle is within the cap and must reschedule the same slot.');
        }
        // Every cycle targets the exact same ID — the chain never grows a
        // new ID space.
        currentAlarmId = wakeCheckId;
      }

      final prefs = await SharedPreferences.getInstance();
      final finalCount = prefs.getInt('wakely_wake_check_count_20');
      expect(finalCount, equals(kMaxWakeCheckReAlerts),
          reason: 'The counter must stop incrementing once the cap is reached, not keep growing forever.');
    });

    test('completing the mission mid-chain resolves the ORIGINAL alarm, not just the re-alert slot', () async {
      // Regression: completeSession() used to call AlarmController.
      // completeAlarm() with whatever alarm ID was currently active, which
      // during a re-alert cycle is the Wake Check slot's ID — an ephemeral
      // quickAlarm record. That path just deletes the ephemeral record and
      // never touches the real alarm, so a recurring alarm would never
      // reschedule and a one-shot would never disable if the user
      // completed the mission on any cycle after the first.
      final alarm = WakelyAlarm(
        id: 21,
        time: DateTime.now(),
        enabled: true,
        type: AlarmType.wakeRoutine,
        mission: MissionConfig(type: MissionType.typing),
        recurrence: Recurrence.none(),
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      await AlarmRepository().save(alarm);

      // Cycle 1: original alarm's native stop schedules the Wake Check slot.
      await WakeSessionController.instance.startSession(21, startAudio: false);
      await WakeSessionController.instance.handleAlarmEvent(AlarmEvent(
        alarmId: 21,
        state: AlarmNativeState.stopped,
        interaction: AlarmInteractionType.stop,
        audioOwnership: AudioOwnership.nativeAlarmKit,
        timestamp: DateTime.now(),
      ));

      final wakeCheckId = wakeCheckAlarmIdFor(21);
      // The user opens the app during the Wake Check re-alert (not the
      // original firing) and completes the mission from there.
      await WakeSessionController.instance.startSession(wakeCheckId, startAudio: false);
      await WakeSessionController.instance.completeSession();

      final original = await AlarmRepository().getById(21);
      expect(original?.enabled, isFalse,
          reason: 'The original alarm must be disabled even though completion happened via the re-alert slot.');
      final leftoverSlot = await AlarmRepository().getById(wakeCheckId);
      expect(leftoverSlot, isNull, reason: 'The Wake Check slot must be cleaned up too.');
    });
  });
}
