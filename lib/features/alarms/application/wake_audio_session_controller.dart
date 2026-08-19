import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:volume_controller/volume_controller.dart';
import '../../sounds/data/sound_repository.dart';
import '../domain/alarm_model.dart';

/// Manages the active audio session while Wakely is foregrounded or explicitly launched.
///
/// This does NOT schedule alarms. It only takes over audio/volume behavior 
/// when a WakeSession begins, providing custom fade-in and passive volume observation.
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
    VolumeController.instance.getVolume().then((v) {
      _systemOutputVolume = v;
      notifyListeners();
    });
    
    _volumeSubscription = VolumeController.instance.addListener((volume) {
      _systemOutputVolume = volume;
      // PASSIVE MONITORING: We do not aggressively force the volume back up.
      // We expose it so the UI can warn the user if they try to turn it down.
      notifyListeners();
    });
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
    
    if (!isTestMode) {
      VolumeController.instance.removeListener();
      await _audioPlayer.stop();
    }
    
    notifyListeners();
  }
}
