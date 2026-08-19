import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../models/mission_settings.dart';

class DefaultMissionConfigScreen extends StatefulWidget {
  final MissionSettings initialSettings;
  final String missionId;
  final String title;
  final IconData icon;
  final Color color;

  const DefaultMissionConfigScreen({
    Key? key,
    required this.initialSettings,
    required this.missionId,
    required this.title,
    required this.icon,
    required this.color,
  }) : super(key: key);

  @override
  State<DefaultMissionConfigScreen> createState() => _DefaultMissionConfigScreenState();
}

class _DefaultMissionConfigScreenState extends State<DefaultMissionConfigScreen> {
  late int _rounds;

  @override
  void initState() {
    super.initState();
    _rounds = widget.initialSettings.missionRounds;
  }

  void _onSave() {
    Haptics.vibrate(HapticsType.success);
    final resultSettings = widget.initialSettings.copyWith(
      mission: widget.missionId,
      missionRounds: _rounds,
    );
    Navigator.pop(context, resultSettings);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('${widget.title} Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            color: Colors.greenAccent,
            onPressed: _onSave,
          ),
        ],
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 80, color: widget.color),
              const SizedBox(height: 32),
              const Text('How many rounds to complete?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 48),
              Text('Rounds: $_rounds', style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: widget.color)),
              const SizedBox(height: 24),
              Slider(
                value: _rounds.toDouble(),
                min: 1,
                max: 10,
                divisions: 9,
                activeColor: widget.color,
                onChanged: (val) {
                  Haptics.vibrate(HapticsType.selection);
                  setState(() => _rounds = val.toInt());
                },
              ),
              const SizedBox(height: 16),
              Text(
                'Complete $_rounds consecutive ${widget.title.toLowerCase()} puzzles to dismiss the alarm.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
