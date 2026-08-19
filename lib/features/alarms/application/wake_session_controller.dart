import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/alarm_model.dart';
import '../domain/alarm_event.dart';
import '../domain/recurrence.dart';
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
  
  AudioOwnership _currentAudioOwnership = AudioOwnership.nativeAlarmKit;
  AudioOwnership get currentAudioOwnership => _currentAudioOwnership;
  
  WakeSessionState _sessionState = WakeSessionState.completed;
  WakeSessionState get sessionState => _sessionState;
  
  bool get isActive => _activeAlarm != null && _sessionState != WakeSessionState.completed && _sessionState != WakeSessionState.emergencyEscaped;

  static final WakeSessionController instance = WakeSessionController._();
  WakeSessionController._();

  static const String _activeSessionKey = 'wakely_active_session_alarm_id';

  /// Deterministic ID for the Wake Check fallback alarm derived from its
  /// parent alarm's ID. Using a fixed offset (rather than an allocated ID)
  /// lets us reliably cancel the fallback later without round-tripping
  /// through persistence to look it up.
  static int wakeCheckAlarmId(int parentAlarmId) => 99999 + parentAlarmId;

  /// Get the ID of a session that was active before the app crashed/closed.
  Future<int?> getDurableActiveSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeSessionKey);
  }

  /// Handles canonical alarm events from the native event normalizer.
  Future<void> handleAlarmEvent(AlarmEvent event) async {
    // Check if we are already active for this alarm and currently own the audio.
    final isCurrentlyActiveForThisAlarm = isActive && _activeAlarm?.id == event.alarmId;
    final currentlyOwnsAudio = _currentAudioOwnership == AudioOwnership.wakely;
    
    // Determine the requested audio ownership.
    var requestedOwnership = event.audioOwnership;
    
    // INVARIANT: Once Wakely owns audio for an active alarm, later nativeAlarmKit events 
    // cannot downgrade ownership back to native.
    if (isCurrentlyActiveForThisAlarm && currentlyOwnsAudio && event.audioOwnership == AudioOwnership.nativeAlarmKit) {
      debugPrint('WakeSessionController: Ignoring downgrade to nativeAlarmKit ownership. Wakely already owns audio for ${event.alarmId}.');
      requestedOwnership = AudioOwnership.wakely;
    }

    _currentAudioOwnership = requestedOwnership;

    if (event.interaction == AlarmInteractionType.stop) {
      debugPrint('WakeSessionController: Native stop received for alarm ${event.alarmId}.');
      final alarm = await AlarmController.instance.getAlarm(event.alarmId);
      if (alarm != null) {
        if (alarm.type == AlarmType.standard) {
          debugPrint('WakeSessionController: Standard alarm stopped natively. Completing session.');
          _activeAlarm = alarm; // temporarily set for completeSession
          await completeSession();
          return;
        } else {
          debugPrint('WakeSessionController: Mission alarm stopped natively. Transitioning to awaitingWakeCheck.');
          _sessionState = WakeSessionState.awaitingWakeCheck;
          // Stop any audio, wait for user to open app or wake check to fire
          await WakeAudioSessionController.instance.stopAudio();
          // We don't start audio. The user must open the app to see the mission.
          notifyListeners();
          
          // Schedule Wake Check fallback alarm for 5 minutes later using AlarmKit
          await _scheduleWakeCheckFallback(alarm);
          return;
        }
      }
    }

    if (requestedOwnership == AudioOwnership.wakely) {
      debugPrint('WakeSessionController: Wakely requested to own audio for alarm ${event.alarmId}.');
      await startSession(event.alarmId, startAudio: true);
    } else if (event.state == AlarmNativeState.firing) {
      debugPrint('WakeSessionController: Alarm ${event.alarmId} is firing natively. Native AlarmKit owns audio.');
      // If we are alive, we intercept the firing state to show the mission UI.
      // BUT we do NOT start custom audio, because AlarmKit is playing natively!
      // This prevents double playback.
      await startSession(event.alarmId, startAudio: false);
    }
  }

  Future<void> _scheduleWakeCheckFallback(WakelyAlarm alarm) async {
    // Schedule a secondary one-shot alarm 5 minutes from now
    // Since we rely on AlarmController which uses PlatformAlarmScheduler,
    // we can schedule a temporary quick alarm to act as the wake check.
    debugPrint('WakeSessionController: Scheduling WakeCheck fallback alarm in 5 minutes.');
    final checkTime = DateTime.now().add(const Duration(minutes: 5));
    final checkAlarm = WakelyAlarm(
      id: wakeCheckAlarmId(alarm.id),
      time: checkTime,
      type: AlarmType.quickAlarm,
      recurrence: Recurrence.none(),
      label: 'Wake Up Check',
      soundId: alarm.soundId,
      volume: 1.0,
      mission: alarm.mission, // Same mission required!
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    // Use the explicit-id path so the fallback alarm's ID stays exactly
    // `wakeCheckAlarmId(alarm.id)` and can be reliably cancelled later —
    // createAlarm() would otherwise overwrite it via AlarmIdAllocator.
    await AlarmController.instance.createAlarmWithExplicitId(checkAlarm);
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
      if (_sessionState == WakeSessionState.completed || _sessionState == WakeSessionState.emergencyEscaped) {
        _sessionState = WakeSessionState.active;
      }
      notifyListeners();
      
      // Persist the active session ID
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt(_activeSessionKey, alarmId);
      
      // UI navigation is handled reactively via the ChangeNotifier's notifyListeners()
      // in main.dart / WakelyApp, ensuring it isn't lost on cold boot.
      debugPrint('WakeSessionController: Wake session started for $alarmId.');
    }
    
    // 4. Start Audio conditionally (This is the Dual-Layer handoff)
    // Even if session is already active, we might need to take over audio
    // if the user just tapped the native notification banner.
    if (startAudio && !WakeAudioSessionController.instance.isActive) {
      debugPrint('WakeSessionController: Taking over audio playback for $alarmId.');
      await WakeAudioSessionController.instance.startAudio(_activeAlarm!, isHandoff: isAlreadyActive);
    }
  }

  /// Stops the active session (audio + UI state) without completing it in the DB.
  /// Useful for crashes, cancellations, or teardowns.
  Future<void> stopSession() async {
    if (_activeAlarm == null) return;
    
    await WakeAudioSessionController.instance.stopAudio();
    _activeAlarm = null;
    _currentAudioOwnership = AudioOwnership.nativeAlarmKit; // Reset ownership
    // Ensure state reflects stopped if it wasn't already marked completed or escaped
    if (_sessionState != WakeSessionState.completed && _sessionState != WakeSessionState.emergencyEscaped) {
      _sessionState = WakeSessionState.completed; // Fallback
    }
    notifyListeners();
    
    // Clear the durable session ID
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_activeSessionKey);
  }

  /// Called when the user successfully completes the Wakely mission.
  /// This officially completes the logical alarm lifecycle.
  Future<void> completeSession() async {
    if (!isActive) return;
    
    final alarmId = _activeAlarm!.id;
    
    // 1. Mark state and stop audio/UI session
    _sessionState = WakeSessionState.completed;
    await stopSession();
    
    // 2. Defer to AlarmController for persistence and recurrence handling
    await AlarmController.instance.completeAlarm(alarmId);

    // Also cancel any wake check alarm that was scheduled
    await AlarmController.instance.deleteAlarm(wakeCheckAlarmId(alarmId));

    debugPrint('WakeSessionController: Mission successful. Session completed for $alarmId.');
  }

  Future<void> emergencyEscape() async {
    if (!isActive) return;
    final alarmId = _activeAlarm!.id;
    debugPrint('WakeSessionController: EMERGENCY ESCAPE triggered for $alarmId.');
    _sessionState = WakeSessionState.emergencyEscaped;
    await stopSession();
    await AlarmController.instance.completeAlarm(alarmId);
    await AlarmController.instance.deleteAlarm(wakeCheckAlarmId(alarmId));
  }
}
