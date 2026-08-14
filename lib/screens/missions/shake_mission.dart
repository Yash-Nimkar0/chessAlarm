import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:sensors_plus/sensors_plus.dart';
import 'dart:async';
import 'dart:math';

import '../../models/mission_settings.dart';

class ShakeMission extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;
  final MissionSettings settings;

  const ShakeMission({
    Key? key,
    required this.onSuccess,
    required this.onSkip,
    required this.settings,
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
    final data = widget.settings.missionData;
    if (data != null && data['shake_count'] != null) {
      _targetShakes = data['shake_count'];
    } else {
      _targetShakes = 30;
    }
    
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
    double progress = (_shakes / _targetShakes).clamp(0.0, 1.0);
    
    return Stack(
      children: [
        // Background Powerup Bar
        Align(
          alignment: Alignment.bottomCenter,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: double.infinity,
            height: MediaQuery.of(context).size.height * progress,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.bottomCenter,
                end: Alignment.topCenter,
                colors: [
                  Colors.orangeAccent.shade700,
                  Colors.yellowAccent,
                ],
              ),
            ),
          ),
        ),
        
        // Content
        Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.vibration, size: 80, color: progress > 0.5 ? Colors.black87 : Colors.orangeAccent),
              const SizedBox(height: 24),
              Text(
                "Shake to Wake!",
                style: TextStyle(
                  color: progress > 0.5 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.surface,
                  fontSize: 32, 
                  fontWeight: FontWeight.bold
                ),
              ),
              const SizedBox(height: 12),
              Text(
                "$_shakes / $_targetShakes shakes",
                style: TextStyle(
                  color: progress > 0.5 ? Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.7) : Theme.of(context).colorScheme.surface.withValues(alpha: 0.7),
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 40),
              Text(
                "${(progress * 100).toInt()}%",
                style: TextStyle(
                  color: progress > 0.5 ? Theme.of(context).colorScheme.onSurface : Theme.of(context).colorScheme.surface,
                  fontSize: 60, 
                  fontWeight: FontWeight.w900
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
