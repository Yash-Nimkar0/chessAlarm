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

  /// Starts the audio session and playback for the given alarm.
  Future<void> startAudio(WakelyAlarm alarm, {bool isHandoff = false}) async {
    if (_isActive) {
      debugPrint('WakeAudioSession already active, ignoring start request.');
      return;
    }

    _isActive = true;
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

    await _initAudioContext();
    _startVolumeObservation();

    final soundId = alarm.soundId;
    final soundModel = SoundRepository.instance.getSoundById(soundId);
    final assetPath = soundModel?.path.replaceFirst('assets/', '') ?? 'audio/alarms/misogi77-ringphone-191692.mp3';

    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    
    // 1. Play first at volume 0 (implicitly or explicitly soon)
    await _audioPlayer.play(AssetSource(assetPath));

    // 2. Set volume immediately after play to avoid iOS race condition
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
        options: {
          AVAudioSessionOptions.mixWithOthers,
          AVAudioSessionOptions.duckOthers,
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
