import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../models/mission_settings.dart';
import '../../theme/design_tokens.dart';

class StepsConfigScreen extends StatefulWidget {
  final MissionSettings initialSettings;

  const StepsConfigScreen({Key? key, required this.initialSettings}) : super(key: key);

  @override
  State<StepsConfigScreen> createState() => _StepsConfigScreenState();
}

class _StepsConfigScreenState extends State<StepsConfigScreen> with SingleTickerProviderStateMixin {
  int _targetSteps = 30;
  late final AnimationController _popController;
  late final Animation<double> _popScale;

  @override
  void initState() {
    super.initState();
    if (widget.initialSettings.mission == 'steps') {
      _targetSteps = widget.initialSettings.missionData?['targetSteps'] ?? 30;
    }
    _popController = AnimationController(vsync: this, duration: const Duration(milliseconds: 300));
    _popScale = Tween<double>(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: _popController, curve: Curves.elasticOut));
  }

  @override
  void dispose() {
    _popController.dispose();
    super.dispose();
  }

  void _save() {
    Haptics.vibrate(HapticsType.medium);
    final newSettings = widget.initialSettings.copyWith(
      mission: 'steps',
      missionData: {
        'targetSteps': _targetSteps,
      },
    );
    Navigator.pop(context, newSettings);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Scaffold(
      appBar: AppBar(
        title: const Text('Steps Mission'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.directions_walk, size: 80, color: Colors.blueAccent),
              const SizedBox(height: 24),
              Text(
                'How many steps?',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'Walk $_targetSteps steps to dismiss the alarm.',
                style: TextStyle(
                  fontSize: 16,
                  color: colorScheme.onSurfaceVariant,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 48),
              
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    onPressed: _targetSteps > 10 ? () {
                      Haptics.vibrate(HapticsType.selection);
                      setState(() => _targetSteps -= 10);
                      _popController.forward(from: 0);
                    } : null,
                    icon: const Icon(Icons.remove_circle_outline),
                    iconSize: 48,
                    color: AppTokens.signal,
                  ),
                  const SizedBox(width: 24),
                  ScaleTransition(
                    scale: _popScale,
                    child: Text(
                      '$_targetSteps',
                      style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.bold,
                        color: AppTokens.signal,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24),
                  IconButton(
                    onPressed: _targetSteps < 200 ? () {
                      Haptics.vibrate(HapticsType.selection);
                      setState(() => _targetSteps += 10);
                      _popController.forward(from: 0);
                    } : null,
                    icon: const Icon(Icons.add_circle_outline),
                    iconSize: 48,
                    color: AppTokens.signal,
                  ),
                ],
              ),
              
              const Spacer(),
              FilledButton(
                onPressed: _save,
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm)),
                ),
                child: const Text('Save Mission', style: TextStyle(fontSize: 18)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
