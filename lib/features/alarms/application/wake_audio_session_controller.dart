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

  static final WakeAudioSessionController instance = WakeAudioSessionController._();
  WakeAudioSessionController._();

  /// Starts the audio session and playback for the given alarm.
  Future<void> startAudio(WakelyAlarm alarm) async {
    if (_isActive) {
      debugPrint('WakeAudioSession already active, ignoring start request.');
      return;
    }

    _isActive = true;
    _currentVolume = 0.0;

    await _initAudioContext();
    _startVolumeObservation();

    final soundId = alarm.soundId;
    final soundModel = SoundRepository.instance.getSoundById(soundId);
    final assetPath = soundModel?.path.replaceFirst('assets/', '') ?? 'audio/alarms/misogi77-ringphone-191692.mp3';

    await _audioPlayer.setVolume(alarm.fadeIn ? 0.0 : 1.0);
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    await _audioPlayer.play(AssetSource(assetPath));

    if (alarm.fadeIn && alarm.fadeDuration > 0) {
      _startFade(alarm.fadeDuration);
    } else {
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
      _audioPlayer.setVolume(_currentVolume);
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
    VolumeController.instance.removeListener();
    
    await _audioPlayer.stop();
    notifyListeners();
  }
}
