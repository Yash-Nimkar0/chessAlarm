import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../domain/alarm_model.dart';
import '../domain/alarm_event.dart';
import '../domain/mission_config.dart';
import '../domain/recurrence.dart';
import '../domain/wake_check_id.dart';
import 'alarm_controller.dart';
import 'wake_audio_session_controller.dart';
import '../../../services/alarm_announcement_service.dart';

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
  
  bool get isActive =>
      _activeAlarm != null &&
      _sessionState != WakeSessionState.completed &&
      _sessionState != WakeSessionState.emergencyEscaped &&
      _sessionState != WakeSessionState.snoozed;

  static final WakeSessionController instance = WakeSessionController._();
  WakeSessionController._();

  static const String _activeSessionKey = 'wakely_active_session_alarm_id';
  static String _wakeCheckCountKey(int originalAlarmId) => 'wakely_wake_check_count_$originalAlarmId';

  // Guards against a stale/duplicate native "stop" event re-opening a
  // session that was already genuinely completed — e.g. if cleanup after
  // completion (AlarmManager.stop() on every Wake Check chain id) turns
  // out to itself trigger the configured stopIntent, or any other source
  // of a late/duplicate callback. Without this, such an event would hit
  // the `else` branch below, overwrite sessionState back to
  // awaitingWakeCheck, and schedule a brand new re-alert for an alarm the
  // user just finished — the worst possible confusing outcome.
  int? _recentlyCompletedOriginalId;
  DateTime? _recentlyCompletedAt;
  static const Duration _completionEchoWindow = Duration(seconds: 10);

  // Mission watchdog: pauses the relentless chain's back half while the
  // user is actively, genuinely engaged with the mission screen, so
  // solving it isn't interrupted by a fresh alert every ~20s — but resumes
  // automatically, either instantly (backgrounding/kill) or after an idle
  // timeout with no interaction, so pausing can never become a way to
  // escape. The chain's own live-tail-kept design (see
  // pauseWakeCheckChain on the native side) means even a hard kill right
  // after pausing still leaves something armed — this Dart-side timer is
  // only responsible for the *normal* resume path, not for safety, which
  // is guaranteed natively regardless of whether this timer ever fires.
  Timer? _missionIdleTimer;
  static const Duration _missionIdleTimeout = Duration(seconds: 90);
  bool _chainPaused = false;

  /// Call when the mission screen genuinely becomes active/visible.
  Future<void> armMissionWatchdog() async {
    if (_activeAlarm == null) return;
    final originalId = originalAlarmIdFor(_activeAlarm!.id);
    _chainPaused = true;
    await AlarmController.instance.pauseWakeCheckChain(originalId);
    _resetMissionIdleTimer();
  }

  /// Call on any meaningful mission interaction (a tap, a correct answer,
  /// a step completed) to keep the pause alive.
  void recordMissionInteraction() {
    if (!_chainPaused) return;
    _resetMissionIdleTimer();
  }

  void _resetMissionIdleTimer() {
    _missionIdleTimer?.cancel();
    _missionIdleTimer = Timer(_missionIdleTimeout, _resumeChainIfPaused);
  }

  Future<void> _resumeChainIfPaused() async {
    if (!_chainPaused || _activeAlarm == null) return;
    _chainPaused = false;
    _missionIdleTimer?.cancel();
    _missionIdleTimer = null;
    final originalId = originalAlarmIdFor(_activeAlarm!.id);
    await AlarmController.instance.resumeWakeCheckChain(originalId);
  }

  /// Call the instant the app is backgrounded or about to be killed while
  /// the watchdog is paused — no grace period, since that's exactly the
  /// scenario the chain exists to survive.
  Future<void> resumeMissionWatchdogImmediately() async {
    await _resumeChainIfPaused();
  }

  /// Deterministic ID for the Wake Check fallback alarm derived from its
  /// parent alarm's ID. Using a fixed offset (rather than an allocated ID)
  /// lets us reliably cancel the fallback later without round-tripping
  /// through persistence to look it up. Normalizes first, so calling this
  /// with an already-offset Wake Check ID still resolves to the same slot.
  static int wakeCheckAlarmId(int parentAlarmId) => wakeCheckAlarmIdFor(parentAlarmId);

  /// Get the ID of a session that was active before the app crashed/closed.
  Future<int?> getDurableActiveSessionId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt(_activeSessionKey);
  }

  /// Clears the durable active-session marker for [originalId] WITHOUT
  /// touching in-memory session state, audio, or notifyListeners() - unlike
  /// stopSession()/completeSession(). For the one specific case where this
  /// marker is discovered stale on cold start: it was left behind by an
  /// abrupt termination (crash, force-stop) that skipped the normal
  /// cleanup, and the platform's own live state confirms nothing is
  /// actually ringing for it any more. Without this, AlarmController's
  /// reconcile would keep trusting the stale marker forever and recover
  /// into a "ringing" mission screen for an alarm that isn't ringing
  /// anywhere - confirmed live, repeatedly.
  Future<void> clearStaleDurableSession(int originalId) async {
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_activeSessionKey) == originalId) {
      await prefs.remove(_activeSessionKey);
    }
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

      final eventOriginalId = originalAlarmIdFor(event.alarmId);
      if (_recentlyCompletedOriginalId == eventOriginalId &&
          _recentlyCompletedAt != null &&
          DateTime.now().difference(_recentlyCompletedAt!) < _completionEchoWindow) {
        debugPrint('WakeSessionController: Ignoring stale native stop for already-completed alarm $eventOriginalId.');
        return;
      }

      // Chain-derived interactions (the vast majority once the chain is
      // running — 30 chain slots vs. 1 reactive slot) have no DB record of
      // their own by design; fall back to the real original alarm's
      // record, which always exists. Without this, any stop interaction
      // that happened to land on a chain entry silently found nothing and
      // did nothing at all — confirmed live: tapping the alert's Stop
      // button opened the app to the plain alarm list with no mission
      // screen and the alarm still ringing.
      final alarm = await AlarmController.instance.getAlarm(event.alarmId) ??
          await AlarmController.instance.getAlarm(eventOriginalId);
      if (alarm != null) {
        // MUST check whether a mission is actually configured
        // (mission.type != none), not alarm.type == AlarmType.standard.
        // EditAlarmScreen lets a mission be attached to ANY alarm type —
        // the "Alarm Mission" section is explicitly available regardless of
        // whether the alarm is a Wake Routine — so a "standard" alarm can
        // still have a real mission. The old check let native Stop
        // silently complete any alarm typed AlarmType.standard even when
        // it had a mission configured, defeating the entire point of
        // setting one: confirmed live — an alarm rang backgrounded+locked
        // and was fully silenced via the native Stop action with no
        // mission enforced at all.
        if (alarm.mission.type == MissionType.none) {
          debugPrint('WakeSessionController: No-mission alarm stopped natively. Completing session.');
          _activeAlarm = alarm; // temporarily set for completeSession
          await completeSession();
          return;
        } else {
          debugPrint('WakeSessionController: Mission alarm stopped natively. Showing mission screen and arming Wake Check fallback.');
          // MUST set _activeAlarm here — without it, isActive stays false
          // (isActive requires _activeAlarm != null), so main.dart's
          // listener has nothing to navigate to. The app would open (the
          // intent's .foreground(.immediate) still launches it) but land on
          // the plain alarm list, doing nothing, until some LATER re-alert
          // happened to fire a real "firing" event that finally set
          // _activeAlarm — a confusing multi-second-or-more delay instead
          // of landing on the mission screen the instant Stop is pressed.
          _activeAlarm = alarm;
          _sessionState = WakeSessionState.awaitingWakeCheck;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt(_activeSessionKey, originalAlarmIdFor(alarm.id));
          // Stop any audio, wait for user to open app or wake check to fire
          await WakeAudioSessionController.instance.stopAudio();
          // We don't start audio. The user must open the app to see the mission.
          notifyListeners();

          // Schedule the Wake Check fallback re-alert.
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

      // Best-effort early announcement: only reachable when the Flutter
      // process was already alive the instant AlarmKit fired (app
      // backgrounded, not killed) — mixed in via duckOthers so it layers
      // over AlarmKit's own native tone rather than silencing it. If the
      // app was killed, this never runs; RingingScreen's own guaranteed
      // trigger still speaks once the user actually opens the alert.
      final firingOriginalId = originalAlarmIdFor(event.alarmId);
      final firingAlarm = await AlarmController.instance.getAlarm(event.alarmId) ??
          await AlarmController.instance.getAlarm(firingOriginalId);
      if (firingAlarm != null) {
        unawaited(AlarmAnnouncementService.maybeSpeak(
          alarmId: firingOriginalId,
          announcementMode: firingAlarm.announcementMode.toStringValue(),
          announceDay: firingAlarm.announceDay,
          announceDate: firingAlarm.announceDate,
          announceTime: firingAlarm.announceTime,
          announceWeather: firingAlarm.announceWeather,
        ));
      }
    }
  }

  Future<void> _scheduleWakeCheckFallback(WakelyAlarm alarm) async {
    // Re-alerts must feel relentless, not like a snooze: short, fixed
    // interval, reusing the SAME native alarm slot every cycle (so the ID
    // space doesn't grow), bounded by a max cycle count so this can't
    // literally spam forever if something goes wrong.
    final originalId = originalAlarmIdFor(alarm.id);
    final prefs = await SharedPreferences.getInstance();
    final cycleCount = (prefs.getInt(_wakeCheckCountKey(originalId)) ?? 0) + 1;

    if (cycleCount > kMaxWakeCheckReAlerts) {
      debugPrint('WakeSessionController: Wake Check re-alert cap ($kMaxWakeCheckReAlerts) reached for $originalId. '
          'Mission remains unresolved but no further automatic re-alert will be scheduled.');
      return;
    }
    await prefs.setInt(_wakeCheckCountKey(originalId), cycleCount);

    debugPrint('WakeSessionController: Scheduling WakeCheck re-alert #$cycleCount/$kMaxWakeCheckReAlerts '
        'in ${kWakeCheckIntervalSeconds}s for $originalId.');
    final checkTime = DateTime.now().add(const Duration(seconds: kWakeCheckIntervalSeconds));
    final checkAlarm = WakelyAlarm(
      id: wakeCheckAlarmIdFor(originalId),
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
    // `wakeCheckAlarmIdFor(originalId)` and can be reliably rescheduled /
    // cancelled later — createAlarm() would otherwise overwrite it via
    // AlarmIdAllocator.
    await AlarmController.instance.createAlarmWithExplicitId(checkAlarm);
  }

  /// Starts a wake session for the given alarm ID if one isn't already active.
  /// If [startAudio] is true, WakeAudioSession takes over playback.
  Future<void> startSession(int alarmId, {bool startAudio = true}) async {
    // 1. Idempotency Check — compared by ORIGINAL id, not raw id: alarmId
    // may be a chain entry's own id (a different number every re-alert
    // slot), which must still count as "the same session" as whatever
    // real alarm id/reactive slot id _activeAlarm is currently tracking.
    final isAlreadyActive = _activeAlarm != null && originalAlarmIdFor(_activeAlarm!.id) == originalAlarmIdFor(alarmId);

    if (isAlreadyActive) {
      debugPrint('WakeSessionController: Session for $alarmId is already active. Checking audio handoff.');
    } else {
      // Prevent overlapping sessions - but ONLY safe to switch tracking away
      // from the current one once ITS mission is actually resolved.
      // stopSession() doesn't touch the previous alarm's native alert at
      // all (it only clears Wakely's own audio/tracking state) and marks
      // its session "completed" as a bare fallback regardless of whether
      // the mission was ever solved. If a second mission alarm fires while
      // the first is still ringing unresolved (allowAlarmOverlap makes
      // this a completely ordinary scenario - e.g. a backup alarm a few
      // minutes after the primary), blindly switching here would silently
      // abandon the first alarm's enforcement: its native alert keeps
      // ringing completely unsupervised - no session, no Wake Check
      // re-arm, nothing - while its own state gets falsely recorded as
      // "completed" even though the mission was never touched. Refusing to
      // switch here costs nothing: the new alarm's own native alert keeps
      // ringing/alerting independently either way (that's the OS/plugin
      // layer, not this tracking), so it isn't silenced by this - only
      // Wakely's own foreground mission screen won't switch to it until
      // the current one is actually resolved.
      final currentUnresolved = isActive &&
          _sessionState != WakeSessionState.completed &&
          _sessionState != WakeSessionState.emergencyEscaped &&
          _sessionState != WakeSessionState.snoozed;
      if (currentUnresolved) {
        debugPrint('WakeSessionController: Alarm ${_activeAlarm?.id} is still active with its mission unresolved - '
            'refusing to hijack tracking for new alarm $alarmId. It keeps ringing natively on its own; '
            'Wakely will pick it up once the current mission is resolved.');
        return;
      }
      if (isActive) {
        debugPrint('WakeSessionController: Another (already-resolved) session is active. Terminating old session first.');
        await stopSession();
      }

      // 2. Fetch full alarm details. Chain-derived ids (the vast majority
      // of interactions once the chain is running) have no DB record of
      // their own by design — fall back to the real original alarm's
      // record, which always exists. Without this, any recovery/handoff
      // that happened to land on a chain entry's id silently found
      // nothing and did nothing (confirmed live: the alert's "Open
      // Wakely" button opened the app to a blank screen instead of the
      // mission screen).
      final alarm = await AlarmController.instance.getAlarm(alarmId) ??
          await AlarmController.instance.getAlarm(originalAlarmIdFor(alarmId));
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
      final prefs = await SharedPreferences.getInstance();
      if (_sessionState == WakeSessionState.completed || _sessionState == WakeSessionState.emergencyEscaped) {
        _sessionState = WakeSessionState.active;
        // Genuinely fresh start (not a Wake Check re-alert continuation) —
        // reset the re-alert cycle count so today's chain doesn't inherit
        // a stale count from a previous morning.
        await prefs.remove(_wakeCheckCountKey(originalAlarmIdFor(alarmId)));
      }
      notifyListeners();

      // Persist the active session ID — always normalized to the ORIGINAL
      // alarm's id, never a Wake Check variant's. AlarmController.reconcile()
      // compares this against each real alarm's own (always-original) id to
      // decide whether it's mid-mission (and should be recovered/left alone)
      // versus genuinely stale (and should be disabled or advanced to its
      // next recurrence). If a later re-alert cycle overwrote this with a
      // reactive Wake Check slot's id instead, that comparison would stop
      // matching the real alarm the next time the app reconciles — which
      // silently disabled/advanced a still-in-progress alarm without the
      // mission ever being completed (confirmed live: alarm showed as
      // completed / jumped to its next occurrence mid wake-session).
      await prefs.setInt(_activeSessionKey, originalAlarmIdFor(alarmId));

      // Claim the audio session immediately — silently, regardless of
      // whether Wakely owns the actual alarm sound yet. This keeps
      // Wakely's own Dart code alive in the background from the instant
      // the alarm fires (see the doc comment on armForWakeSession for why
      // that matters), so volume-floor enforcement is protecting the
      // alarm from the very first ring, not just after a later handoff.
      await WakeAudioSessionController.instance.armForWakeSession(alarm);

      // UI navigation is handled reactively via the ChangeNotifier's notifyListeners()
      // in main.dart / WakelyApp, ensuring it isn't lost on cold boot.
      debugPrint('WakeSessionController: Wake session started for $alarmId.');
    }

    // 4. Start Audio conditionally (This is the Dual-Layer handoff)
    // Even if the session (and the armed, silent audio session) is already
    // active, we might need to take over AUDIBLE audio if the user just
    // tapped the native notification banner — gate on isAudible, not
    // isActive, since arming alone must not suppress this.
    if (startAudio && !WakeAudioSessionController.instance.isAudible) {
      debugPrint('WakeSessionController: Taking over audio playback for $alarmId.');
      await WakeAudioSessionController.instance.startAudio(_activeAlarm!, isHandoff: isAlreadyActive);
    }
  }

  /// Stops the active session (audio + UI state) without completing it in the DB.
  /// Useful for crashes, cancellations, or teardowns.
  Future<void> stopSession() async {
    if (_activeAlarm == null) return;

    _missionIdleTimer?.cancel();
    _missionIdleTimer = null;
    _chainPaused = false;

    await WakeAudioSessionController.instance.stopAudio();
    _activeAlarm = null;
    _currentAudioOwnership = AudioOwnership.nativeAlarmKit; // Reset ownership
    // Ensure state reflects stopped if it wasn't already marked completed, escaped, or snoozed
    if (_sessionState != WakeSessionState.completed &&
        _sessionState != WakeSessionState.emergencyEscaped &&
        _sessionState != WakeSessionState.snoozed) {
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

    // The active session's alarm might itself be a Wake Check re-alert
    // (the user could complete the mission on cycle #3, not the original
    // firing) — completion must always resolve back to the ORIGINAL
    // alarm's own record, or a recurring alarm would never reschedule and
    // a one-shot would never disable; only the ephemeral Wake Check record
    // would get cleaned up.
    final originalId = originalAlarmIdFor(_activeAlarm!.id);
    _recentlyCompletedOriginalId = originalId;
    _recentlyCompletedAt = DateTime.now();

    // 1. Mark state and stop audio/UI session
    _sessionState = WakeSessionState.completed;
    await stopSession();

    // 2. Defer to AlarmController for persistence and recurrence handling
    await AlarmController.instance.completeAlarm(originalId);

    // Also cancel the Wake Check alarm slot (reused across every re-alert
    // cycle, so this single delete cleans up regardless of which cycle we
    // were on), the entire pre-scheduled chain (see cancelWakeCheckChain —
    // the native-side chain that survives even a hardware-button kill also
    // needs explicit cleanup so it doesn't keep ringing after a genuine
    // completion), and reset the cycle counter.
    await AlarmController.instance.deleteAlarm(wakeCheckAlarmIdFor(originalId));
    await AlarmController.instance.cancelWakeCheckChain(originalId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wakeCheckCountKey(originalId));

    debugPrint('WakeSessionController: Mission successful. Session completed for $originalId.');
  }

  Future<void> emergencyEscape() async {
    if (!isActive) return;
    final originalId = originalAlarmIdFor(_activeAlarm!.id);
    debugPrint('WakeSessionController: EMERGENCY ESCAPE triggered for $originalId.');
    _recentlyCompletedOriginalId = originalId;
    _recentlyCompletedAt = DateTime.now();
    _sessionState = WakeSessionState.emergencyEscaped;
    await stopSession();
    await AlarmController.instance.completeAlarm(originalId);
    await AlarmController.instance.deleteAlarm(wakeCheckAlarmIdFor(originalId));
    await AlarmController.instance.cancelWakeCheckChain(originalId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wakeCheckCountKey(originalId));
  }

  /// Short, limited deferral (AlarmController.snoozeAlarm) - reschedules the
  /// same alarm to fire again shortly, rather than completing it. Returns
  /// false without changing any state if the alarm has used up its snooze
  /// budget for this ring cycle, so the caller can show "no snoozes left"
  /// and leave the session running untouched.
  Future<bool> snoozeSession() async {
    if (!isActive) return false;
    final originalId = originalAlarmIdFor(_activeAlarm!.id);

    final snoozed = await AlarmController.instance.snoozeAlarm(originalId);
    if (!snoozed) return false;

    debugPrint('WakeSessionController: Snoozed for $originalId.');
    _recentlyCompletedOriginalId = originalId;
    _recentlyCompletedAt = DateTime.now();
    _sessionState = WakeSessionState.snoozed;
    await stopSession();

    // Same cleanup completeSession/emergencyEscape do: this ring cycle's
    // Wake Check chain must not keep re-alerting on its own and race with
    // the alarm firing fresh again after the snooze duration.
    await AlarmController.instance.deleteAlarm(wakeCheckAlarmIdFor(originalId));
    await AlarmController.instance.cancelWakeCheckChain(originalId);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_wakeCheckCountKey(originalId));
    return true;
  }
}
