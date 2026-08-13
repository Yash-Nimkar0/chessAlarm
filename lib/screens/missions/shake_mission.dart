import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';

class ShakeMission extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;
  final int difficulty;

  const ShakeMission({
    Key? key,
    required this.onSuccess,
    required this.onSkip,
    required this.difficulty,
  }) : super(key: key);

  @override
  State<ShakeMission> createState() => _ShakeMissionState();
}

class _ShakeMissionState extends State<ShakeMission> {
  StreamSubscription? _accelSub;
  int _shakes = 0;
  late int _targetShakes;
  
  static const double shakeThreshold = 15.0; // Acceleration magnitude to count as a shake
  DateTime _lastShakeTime = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Default 30 shakes, difficulty scales it
    _targetShakes = 15 + (widget.difficulty / 20).toInt();
    
    _accelSub = userAccelerometerEventStream(samplingPeriod: SensorInterval.gameInterval).listen((event) {
      double magnitude = sqrt(event.x * event.x + event.y * event.y + event.z * event.z);
      if (magnitude > shakeThreshold) {
        final now = DateTime.now();
        if (now.difference(_lastShakeTime).inMilliseconds > 200) { // Debounce
          _lastShakeTime = now;
          setState(() {
            _shakes++;
          });
          Haptics.vibrate(HapticsType.light);
          if (_shakes >= _targetShakes) {
            _accelSub?.cancel();
            Haptics.vibrate(HapticsType.success);
            widget.onSuccess();
          }
        }
      }
    });
  }

  @override
  void dispose() {
    _accelSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    double progress = _shakes / _targetShakes;
    
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.vibration, size: 80, color: Colors.orangeAccent),
        const SizedBox(height: 24),
        const Text(
          "Shake to Wake!",
          style: TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "$_shakes / $_targetShakes shakes",
          style: const TextStyle(color: Colors.white70, fontSize: 20),
        ),
        const SizedBox(height: 60),
        Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 200,
              height: 200,
              child: CircularProgressIndicator(
                value: progress,
                strokeWidth: 20,
                backgroundColor: Colors.white.withOpacity(0.1),
                color: Colors.orangeAccent,
              ),
            ),
            Text(
              "${(progress * 100).toInt()}%",
              style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ],
    );
  }
}
