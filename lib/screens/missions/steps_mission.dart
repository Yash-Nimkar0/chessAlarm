import 'dart:async';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'package:pedometer/pedometer.dart';

class StepsMission extends StatefulWidget {
  final Map<String, dynamic> missionData;
  final VoidCallback onSuccess;
  final VoidCallback onSkip;

  const StepsMission({
    Key? key,
    required this.missionData,
    required this.onSuccess,
    required this.onSkip,
  }) : super(key: key);

  @override
  State<StepsMission> createState() => _StepsMissionState();
}

class _StepsMissionState extends State<StepsMission> {
  late Stream<StepCount> _stepCountStream;
  StreamSubscription<StepCount>? _subscription;
  
  int _targetSteps = 30;
  int _initialSteps = -1;
  int _currentSteps = 0;
  bool _isSuccess = false;
  bool _hasError = false;

  @override
  void initState() {
    super.initState();
    _targetSteps = widget.missionData['targetSteps'] ?? 30;
    _initPedometer();
  }

  void _initPedometer() {
    _stepCountStream = Pedometer.stepCountStream;
    _subscription = _stepCountStream.listen(_onStepCount, onError: _onStepCountError);
  }

  void _onStepCount(StepCount event) {
    if (_isSuccess) return;

    if (_initialSteps == -1) {
      _initialSteps = event.steps;
    }

    final takenSteps = event.steps - _initialSteps;
    
    if (takenSteps != _currentSteps) {
      setState(() {
        _currentSteps = takenSteps;
      });
      Haptics.vibrate(HapticsType.light);
      
      if (_currentSteps >= _targetSteps) {
        _markSuccess();
      }
    }
  }

  void _onStepCountError(error) {
    if (!mounted) return;
    setState(() {
      _hasError = true;
    });
  }

  void _markSuccess() {
    setState(() {
      _isSuccess = true;
    });
    _subscription?.cancel();
    Haptics.vibrate(HapticsType.success);
    widget.onSuccess();
  }
  
  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final double progress = (_currentSteps / _targetSteps).clamp(0.0, 1.0);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(24.0),
          child: Text(
            'Walk $_targetSteps steps!',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              color: colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        Expanded(
          child: Center(
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: 250,
                  height: 250,
                  child: CircularProgressIndicator(
                    value: progress,
                    strokeWidth: 20,
                    backgroundColor: colorScheme.surfaceContainerHighest,
                    color: Colors.blueAccent,
                  ),
                ),
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.directions_walk, size: 64, color: Colors.blueAccent),
                    const SizedBox(height: 8),
                    if (_hasError)
                      Text(
                        'Sensor Error',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.error,
                        ),
                      )
                    else
                      Text(
                        '$_currentSteps / $_targetSteps',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                          color: colorScheme.onSurface,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        TextButton(
          onPressed: widget.onSkip,
          child: Text('Skip (-10 Points)', style: TextStyle(color: colorScheme.error, fontSize: 16)),
        ),
      ],
    );
  }
}
