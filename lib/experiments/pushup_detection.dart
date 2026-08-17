import 'dart:async';
import 'package:flutter/material.dart';
import 'package:sensors_plus/sensors_plus.dart';

class PushupDetectionExperiment extends StatefulWidget {
  const PushupDetectionExperiment({Key? key}) : super(key: key);

  @override
  State<PushupDetectionExperiment> createState() => _PushupDetectionExperimentState();
}

class _PushupDetectionExperimentState extends State<PushupDetectionExperiment> {
  int _pushups = 0;
  bool _isDown = false;
  
  // Z-axis thresholds for phone flat on ground
  // Gravity is roughly 9.8 m/s^2
  // When phone is flat on the ground and user moves down, acceleration decreases or increases depending on motion.
  // Actually, pushups are best detected by placing the phone under the chest and tapping the screen with the nose/chest,
  // OR using the proximity sensor (not available in standard plugins without custom code),
  // OR using accelerometer peaks (Z axis drops during descent, spikes on stop/push).
  
  double _currentZ = 0.0;
  StreamSubscription<UserAccelerometerEvent>? _accelSubscription;
  
  @override
  void initState() {
    super.initState();
    _startDetection();
  }

  void _startDetection() {
    _accelSubscription = userAccelerometerEventStream().listen((event) {
      if (!mounted) return;
      setState(() {
        _currentZ = event.z;
      });

      // Simple threshold logic:
      // A pushup has a downward phase (negative Z acceleration) followed by an upward phase.
      // This is highly experimental and will need physical testing.
      if (event.z < -2.0) {
        _isDown = true;
      } else if (_isDown && event.z > 2.0) {
        setState(() {
          _pushups++;
          _isDown = false;
        });
      }
    });
  }

  @override
  void dispose() {
    _accelSubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Push-up Experiment')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Place phone on floor under your chest.', style: TextStyle(fontSize: 16)),
            const SizedBox(height: 32),
            Text('Push-ups: $_pushups', style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold)),
            const SizedBox(height: 32),
            Text('Current Z-Accel: ${_currentZ.toStringAsFixed(2)}'),
            const SizedBox(height: 16),
            Text('State: ${_isDown ? "Going Down" : "Up"}', style: TextStyle(color: _isDown ? Colors.red : Colors.green)),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () => setState(() {
                _pushups = 0;
                _isDown = false;
              }),
              child: const Text('Reset'),
            )
          ],
        ),
      ),
    );
  }
}
