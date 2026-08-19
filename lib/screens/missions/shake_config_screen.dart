import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../models/mission_settings.dart';

class ShakeConfigScreen extends StatefulWidget {
  final MissionSettings initialSettings;

  const ShakeConfigScreen({Key? key, required this.initialSettings}) : super(key: key);

  @override
  State<ShakeConfigScreen> createState() => _ShakeConfigScreenState();
}

class _ShakeConfigScreenState extends State<ShakeConfigScreen> {
  late int _shakeCount;
  
  // Available shake options from 5 to 50
  final List<int> _shakeOptions = List.generate(46, (index) => index + 5);

  @override
  void initState() {
    super.initState();
    // Load existing shake count or default to 30
    final data = widget.initialSettings.missionData;
    if (data != null && data['shake_count'] != null) {
      _shakeCount = data['shake_count'];
    } else {
      _shakeCount = 30; // Default
    }
  }

  void _onSave() {
    Haptics.vibrate(HapticsType.success);
    
    final updatedData = Map<String, dynamic>.from(widget.initialSettings.missionData ?? {});
    updatedData['shake_count'] = _shakeCount;

    final resultSettings = widget.initialSettings.copyWith(
      mission: 'shake',
      missionData: updatedData,
    );
    Navigator.pop(context, resultSettings);
  }

  @override
  Widget build(BuildContext context) {
    int initialIndex = _shakeOptions.indexOf(_shakeCount);
    if (initialIndex == -1) initialIndex = 25; // default 30

    return Scaffold(
      appBar: AppBar(
        title: const Text('Shake Mission Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.check),
            color: Colors.greenAccent,
            onPressed: _onSave,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.vibration, size: 80, color: Colors.orangeAccent),
            const SizedBox(height: 32),
            const Text('How many shakes to wake up?', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            const SizedBox(height: 48),
            SizedBox(
              height: 200,
              child: CupertinoPicker(
                scrollController: FixedExtentScrollController(initialItem: initialIndex),
                itemExtent: 60,
                onSelectedItemChanged: (index) {
                  Haptics.vibrate(HapticsType.selection);
                  setState(() {
                    _shakeCount = _shakeOptions[index];
                  });
                },
                children: _shakeOptions.map((count) {
                  return Center(
                    child: Text(
                      '$count',
                      style: TextStyle(
                        fontSize: _shakeCount == count ? 40 : 28,
                        fontWeight: _shakeCount == count ? FontWeight.bold : FontWeight.normal,
                        color: _shakeCount == count ? Colors.orangeAccent : Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 48),
            Text(
              'Shake your phone strongly $_shakeCount times to dismiss the alarm.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }
}
