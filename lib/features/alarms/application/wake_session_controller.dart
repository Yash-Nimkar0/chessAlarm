import 'dart:async';
import 'package:flutter/foundation.dart';
import '../domain/alarm_model.dart';
import '../domain/alarm_event.dart';
import '../data/alarm_repository.dart';
import 'alarm_controller.dart';
import 'wake_audio_session_controller.dart';

/// Manages the logical lifecycle of an active wake experience.
///
/// Ensures idempotency (avoids duplicate navigation/audio) when receiving 
/// multiple native triggers for the same alarm (e.g. AlarmKit fires + StopIntent).
class WakeSessionController extends ChangeNotifier {
  WakelyAlarm? _activeAlarm;
  WakelyAlarm? get activeAlarm => _activeAlarm;
  
  bool get isActive => _activeAlarm != null;

  // Stream for UI handoff (e.g., main.dart listener)
  final _sessionStreamController = StreamController<WakelyAlarm>.broadcast();
  Stream<WakelyAlarm> get sessionStream => _sessionStreamController.stream;

  static final WakeSessionController instance = WakeSessionController._();
  WakeSessionController._();

  /// Handles canonical alarm events from the native event normalizer.
  Future<void> handleAlarmEvent(AlarmEvent event) async {
    // Determine if we need to start or recover a session.
    // 1. If user explicitly interacted (tapped the notification), always start.
    // 2. If it's a firing state update while the app is alive, start automatically.
    
    if (event.interaction == AlarmInteractionType.stop) {
      debugPrint('WakeSessionController: Received interaction for alarm ${event.alarmId}');
      // User tapped Stop on native UI -> Native audio stopped natively -> We own audio now
      await startSession(event.alarmId, startAudio: true);
    } else if (event.state == AlarmNativeState.firing) {
      debugPrint('WakeSessionController: Alarm ${event.alarmId} is firing natively.');
      // If we are alive, we intercept the firing state to show the mission UI.
      // BUT we do NOT start custom audio, because AlarmKit is playing natively!
      // This prevents double playback.
      await startSession(event.alarmId, startAudio: false);
    }
  }

  /// Starts a wake session for the given alarm ID if one isn't already active.
  /// If [startAudio] is true, WakeAudioSession takes over playback.
  Future<void> startSession(int alarmId, {bool startAudio = true}) async {
    // 1. Idempotency Check
    final isAlreadyActive = (_activeAlarm?.id == alarmId);
    
    if (isAlreadyActive) {
      debugPrint('WakeSessionController: Session for $alarmId is already active. Checking audio handoff.');
    } else {
      // Prevent overlapping sessions (highly unlikely, but safe)
      if (isActive) {
        debugPrint('WakeSessionController: Another session is active. Terminating old session first.');
        await stopSession();
      }

      // 2. Fetch full alarm details
      final alarm = await AlarmController.instance.getAlarm(alarmId);
      if (alarm == null) {
        debugPrint('WakeSessionController: Alarm $alarmId not found in persistence. Cannot start session.');
        return;
      }

      if (!alarm.enabled && alarm.type != AlarmType.quickAlarm) {
        debugPrint('WakeSessionController: Alarm $alarmId is disabled. Ignoring start request.');
        return;
      }

      // 3. Initialize Session if brand new
      _activeAlarm = alarm;
      notifyListeners();
      
      // 5. Notify UI to navigate
      _sessionStreamController.add(alarm);
      debugPrint('WakeSessionController: Wake session started for $alarmId.');
    }
    
    // 4. Start Audio conditionally (This is the Dual-Layer handoff)
    // Even if session is already active, we might need to take over audio
    // if the user just tapped the native notification banner.
    if (startAudio && !WakeAudioSessionController.instance.isActive) {
      debugPrint('WakeSessionController: Taking over audio playback for $alarmId.');
      await WakeAudioSessionController.instance.startAudio(_activeAlarm!);
    }
  }

  /// Stops the active session (audio + UI state) without completing it in the DB.
  /// Useful for crashes, cancellations, or teardowns.
  Future<void> stopSession() async {
    if (!isActive) return;
    
    await WakeAudioSessionController.instance.stopAudio();
    _activeAlarm = null;
    notifyListeners();
  }

  /// Called when the user successfully completes the Wakely mission.
  /// This officially completes the logical alarm lifecycle.
  Future<void> completeSession() async {
    if (!isActive) return;
    
    final alarmId = _activeAlarm!.id;
    
    // 1. Stop audio/UI session
    await stopSession();
    
    // 2. Defer to AlarmController for persistence and recurrence handling
    await AlarmController.instance.completeAlarm(alarmId);
    
    debugPrint('WakeSessionController: Mission successful. Session completed for $alarmId.');
  }
}
