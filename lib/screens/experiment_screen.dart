import 'dart:async';
import 'package:flutter/material.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:volume_controller/volume_controller.dart';
import '../features/sounds/data/sound_repository.dart';

class ExperimentScreen extends StatefulWidget {
  const ExperimentScreen({Key? key}) : super(key: key);

  @override
  State<ExperimentScreen> createState() => _ExperimentScreenState();
}

class _ExperimentScreenState extends State<ExperimentScreen> {
  // Experiment A: Fade
  final AudioPlayer _audioPlayer = AudioPlayer();
  Timer? _fadeTimer;
  double _playbackVolume = 0.0;
  int _elapsedFadeSeconds = 0;
  int _targetFadeSeconds = 0;
  bool _isPlaying = false;

  // Experiment B: Volume Observation
  double _systemVolume = 0.0;
  StreamSubscription<double>? _volumeSubscription;

  @override
  void initState() {
    super.initState();
    _initAudioSession();
    _initVolumeObservation();
  }

  Future<void> _initAudioSession() async {
    // We configure AudioPlayer to act like an alarm (AlarmKit alternative)
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

  void _initVolumeObservation() {
    VolumeController.instance.getVolume().then((v) {
      if (mounted) setState(() => _systemVolume = v);
    });
    
    // Listen to hardware volume button changes
    _volumeSubscription = VolumeController.instance.addListener((volume) {
      if (mounted) {
        setState(() {
          _systemVolume = volume;
        });
      }
    });
  }

  @override
  void dispose() {
    _fadeTimer?.cancel();
    _audioPlayer.dispose();
    _volumeSubscription?.cancel();
    VolumeController.instance.removeListener();
    super.dispose();
  }

  Future<void> _startFadeExperiment(int durationSeconds) async {
    _fadeTimer?.cancel();
    await _audioPlayer.stop();

    setState(() {
      _isPlaying = true;
      _playbackVolume = 0.0;
      _elapsedFadeSeconds = 0;
      _targetFadeSeconds = durationSeconds;
    });

    await _audioPlayer.setVolume(0.0);
    // Play celestial (long sound)
    final soundPath = SoundRepository.instance.getAvailableSounds().firstWhere((s) => s.id == 'wakely_celestial').path;
    await _audioPlayer.play(AssetSource(soundPath.replaceFirst('assets/', '')));

    // Simple manual fade loop (since Audioplayers doesn't have a native fade curve yet)
    _fadeTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      
      setState(() {
        _elapsedFadeSeconds++;
        _playbackVolume = (_elapsedFadeSeconds / _targetFadeSeconds).clamp(0.0, 1.0);
      });
      
      _audioPlayer.setVolume(_playbackVolume);

      if (_elapsedFadeSeconds >= _targetFadeSeconds) {
        timer.cancel();
      }
    });
  }

  Future<void> _stopAudio() async {
    _fadeTimer?.cancel();
    await _audioPlayer.stop();
    setState(() {
      _isPlaying = false;
      _playbackVolume = 0.0;
      _elapsedFadeSeconds = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Wake Audio Experiments'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // EXPERIMENT A
            const Text('Experiment A: Fade Integration', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tests if AVAudioPlayer can cleanly fade-in from 0 to 100% volume over long durations when app is alive.'),
            const SizedBox(height: 16),
            
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('Audio Player Volume: ${(_playbackVolume * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 24)),
                  Text('Time: $_elapsedFadeSeconds / $_targetFadeSeconds sec', style: const TextStyle(fontSize: 16)),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(value: _playbackVolume),
                ],
              ),
            ),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ElevatedButton(
                  onPressed: _isPlaying ? null : () => _startFadeExperiment(15),
                  child: const Text('15s Fade'),
                ),
                ElevatedButton(
                  onPressed: _isPlaying ? null : () => _startFadeExperiment(30),
                  child: const Text('30s Fade'),
                ),
                ElevatedButton(
                  onPressed: _isPlaying ? null : () => _startFadeExperiment(60),
                  child: const Text('60s Fade'),
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade100),
              onPressed: _stopAudio,
              child: const Text('Stop Audio'),
            ),

            const Divider(height: 48, thickness: 2),

            // EXPERIMENT B
            const Text('Experiment B: Hardware Volume Observation', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text('Tests if Wakely can passively observe system hardware volume changes using public APIs (AVAudioSession outputVolume).'),
            const SizedBox(height: 16),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: [
                  Text('System Output Volume', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                  Text('${(_systemVolume * 100).toStringAsFixed(0)}%', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  LinearProgressIndicator(
                    value: _systemVolume, 
                    color: _systemVolume < 0.2 ? Colors.red : Colors.green,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              '1. Start audio above.\n2. Press hardware volume UP/DOWN.\n3. Verify if system volume is detected while foreground, backgrounded, and locked.',
              style: TextStyle(height: 1.5),
            ),
          ],
        ),
      ),
    );
  }
}
