import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:volume_controller/volume_controller.dart';
import '../../sounds/data/sound_repository.dart';
import '../domain/alarm_model.dart';

/// Manages the active audio session while Wakely is foregrounded or explicitly launched.
///
/// This does NOT schedule alarms. It only takes over audio/volume behavior
/// when a WakeSession begins, providing custom fade-in and volume-floor enforcement.
class WakeAudioSessionController extends ChangeNotifier {
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _fadeTimer;
  StreamSubscription<double>? _volumeSubscription;

  bool _isActive = false;
  bool get isActive => _isActive;

  /// True once volume has actually been raised beyond the silent arm
  /// (i.e. [startAudio] has run), as opposed to just [armForWakeSession]
  /// having claimed the session. Callers that gate on "should I call
  /// startAudio()" must check this, not [isActive] — arming alone must not
  /// suppress the later real takeover.
  bool _isAudible = false;
  bool get isAudible => _isAudible;

  double _currentVolume = 0.0;
  double get currentVolume => _currentVolume;

  double _systemOutputVolume = 0.0;
  double get systemOutputVolume => _systemOutputVolume;

  /// Minimum system output volume enforced while a wake session is active.
  /// Set once when the session starts (see [_startVolumeObservation]);
  /// never lowered for the duration of the session, only ever raised if the
  /// user turns the volume up further. Public API only (MPVolumeView's
  /// embedded UISlider, via the `volume_controller` package) — no private
  /// APIs, and scoped to only while a wake session is actually ringing.
  double _volumeFloor = 0.0;

  /// True whenever the last volume-floor enforcement actually had to push
  /// the system volume back up (i.e. the user just tried to lower it).
  /// Exposed for UI/diagnostic feedback.
  bool wasVolumeRestored = false;

  bool get isFading => _fadeTimer != null && _fadeTimer!.isActive;

  static final WakeAudioSessionController instance = WakeAudioSessionController._();
  WakeAudioSessionController._();

  @visibleForTesting
  bool isTestMode = false;

  /// Immediately claims the audio session and starts silent (volume 0)
  /// looped playback the instant a wake session begins — even before
  /// Wakely has taken over from AlarmKit's native sound, and regardless of
  /// whether it ever does before the mission is resolved.
  ///
  /// This exists specifically to keep Wakely's own Dart code alive in the
  /// background: iOS only honors the `audio` UIBackgroundMode entitlement
  /// while the app is actually engaged in playback through its own
  /// AVAudioSession. Without an active session from the very first moment
  /// the alarm fires, the app can be suspended by iOS within seconds of
  /// backgrounding — before any handoff ever happens — which means
  /// everything else in this class (volume-floor enforcement included)
  /// would simply never run. Volume stays at 0 so nothing audible doubles
  /// up with AlarmKit's own native alert sound; [startAudio] raises it.
  ///
  /// Idempotent — safe to call even if already armed or fully active.
  Future<void> armForWakeSession(WakelyAlarm alarm) async {
    if (_isActive) return;
    _isActive = true;

    if (isTestMode) {
      notifyListeners();
      return;
    }

    await _initAudioContext();
    _startVolumeObservation();

    final soundModel = SoundRepository.instance.getSoundById(alarm.soundId);
    final assetPath = soundModel?.path.replaceFirst('assets/', '') ?? 'audio/alarms/misogi77-ringphone-191692.mp3';

    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource(assetPath));
    await _audioPlayer.setVolume(0.0);
    notifyListeners();
  }

  /// Raises the session to full audible playback for [alarm], applying
  /// fade-in per its configuration. Arms first (silently) if that hasn't
  /// already happened, so this remains safe to call directly on its own.
  Future<void> startAudio(WakelyAlarm alarm, {bool isHandoff = false}) async {
    if (_isAudible) {
      debugPrint('WakeAudioSession already audible, ignoring start request.');
      return;
    }

    if (!_isActive) {
      await armForWakeSession(alarm);
    }
    _isAudible = true;
    _currentVolume = 0.0;

    // User configuration
    final bool userFadeIn = alarm.fadeIn;
    final int userFadeDuration = alarm.fadeDuration;

    // Technical transition
    // If handoff and user fade is OFF, apply a short 2s transition to avoid abrupt restart
    final bool shouldFade = userFadeIn || isHandoff;
    final int effectiveFadeDuration = userFadeIn ? userFadeDuration : (isHandoff ? 2 : 0);

    if (isTestMode) {
      if (shouldFade && effectiveFadeDuration > 0) {
        _startFade(effectiveFadeDuration);
      } else {
        _currentVolume = 1.0;
        notifyListeners();
      }
      return;
    }

    // The player is already running (silently, from armForWakeSession) —
    // just raise its volume, no need to call play() again.
    if (shouldFade && effectiveFadeDuration > 0) {
      await _audioPlayer.setVolume(0.0);
      _startFade(effectiveFadeDuration);
    } else {
      await _audioPlayer.setVolume(1.0);
      _currentVolume = 1.0;
      notifyListeners();
    }
  }

  Future<void> _initAudioContext() async {
    await _audioPlayer.setAudioContext(AudioContext(
      iOS: AudioContextIOS(
        category: AVAudioSessionCategory.playback,
        // mixWithOthers only — deliberately NOT duckOthers. This session
        // now activates immediately when a wake session starts, at the
        // same time AlarmKit's own native sound may be alerting; ducking
        // is unverified to leave AlarmKit's system-level alert alone, and
        // the downside of getting that wrong (quietly lowering the one
        // sound this whole feature depends on) is not worth whatever
        // ducking would buy us against third-party apps.
        options: {
          AVAudioSessionOptions.mixWithOthers,
        },
      ),
      android: const AudioContextAndroid(
        isSpeakerphoneOn: true,
        stayAwake: true,
        contentType: AndroidContentType.sonification,
        usageType: AndroidUsageType.alarm,
        audioFocus: AndroidAudioFocus.gainTransientExclusive,
      ),
    ));
  }

  void _startVolumeObservation() {
    VolumeController.instance.showSystemUI = false;

    VolumeController.instance.getVolume().then((v) {
      _systemOutputVolume = v;
      // Floor is whatever the volume already was when the session started,
      // raised to a sensible minimum so a session that began at a very low
      // (or muted) system volume still ends up loud enough to matter. Never
      // forced all the way to max — a user who deliberately keeps their
      // media volume at, say, 70% keeps that as their ceiling; they just
      // can't drop below it while this alarm is ringing.
      _volumeFloor = v < 0.5 ? 0.5 : v;
      notifyListeners();
    });

    _volumeSubscription = VolumeController.instance.addListener((volume) {
      final decision = evaluateVolumeChange(floor: _volumeFloor, observedVolume: volume);
      _volumeFloor = decision.newFloor;
      wasVolumeRestored = decision.correctedValue != null;

      if (decision.correctedValue != null) {
        // The user just pressed volume-down (or the hardware otherwise
        // lowered it) while this alarm is actively ringing. Push it back up
        // immediately — this is the actual "you cannot silence it with the
        // volume button" behavior. Only active for the lifetime of this
        // WakeAudioSession; stopAudio() tears the listener down entirely,
        // so normal app/media volume control is completely unaffected
        // outside of an active alarm.
        VolumeController.instance.setVolume(decision.correctedValue!);
        _systemOutputVolume = decision.correctedValue!;
      } else {
        _systemOutputVolume = volume;
      }

      notifyListeners();
    });
  }

  /// Pure decision logic for volume-floor enforcement, split out from
  /// [_startVolumeObservation] so it's directly testable without needing to
  /// mock the full audioplayers playback pipeline (which
  /// [_startVolumeObservation] runs alongside in the real flow).
  ///
  /// Returns the value to push back via VolumeController.setVolume() (or
  /// null if [observedVolume] doesn't need correcting), and the floor to
  /// use for the next comparison.
  @visibleForTesting
  static ({double? correctedValue, double newFloor}) evaluateVolumeChange({
    required double floor,
    required double observedVolume,
  }) {
    if (observedVolume < floor - 0.01) {
      return (correctedValue: floor, newFloor: floor);
    }
    return (correctedValue: null, newFloor: observedVolume > floor ? observedVolume : floor);
  }

  void _startFade(int durationSeconds) {
    int elapsed = 0;
    _fadeTimer?.cancel();
    
    _fadeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      elapsed++;
      _currentVolume = (elapsed / durationSeconds).clamp(0.0, 1.0);
      
      if (!isTestMode) {
        _audioPlayer.setVolume(_currentVolume);
      }
      
      notifyListeners();

      if (elapsed >= durationSeconds) {
        timer.cancel();
      }
    });
  }

  /// Stops playback, clears timers, and tears down the audio session.
  Future<void> stopAudio() async {
    if (!_isActive) return;

    _isActive = false;
    _isAudible = false;
    _fadeTimer?.cancel();
    _volumeSubscription?.cancel();
    _volumeFloor = 0.0;
    wasVolumeRestored = false;

    if (!isTestMode) {
      VolumeController.instance.removeListener();
      await _audioPlayer.stop();
    }

    notifyListeners();
  }
}
