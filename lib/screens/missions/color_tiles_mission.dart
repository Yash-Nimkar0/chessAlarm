import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'dart:math';

import '../../models/mission_settings.dart';

class ColorTilesMission extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;
  final MissionSettings settings;

  const ColorTilesMission({
    Key? key,
    required this.onSuccess,
    required this.onSkip,
    required this.settings,
  }) : super(key: key);

  @override
  State<ColorTilesMission> createState() => _ColorTilesMissionState();
}

class _ColorTilesMissionState extends State<ColorTilesMission> {
  final Random _random = Random();
  late List<Color> _gridColors;
  late List<bool> _selectedTiles;
  late Color _targetColor;
  late int _targetCount;
  
  int _currentRound = 0;
  late int _totalRounds;
  
  final List<Color> _availableColors = [
    Colors.redAccent,
    Colors.greenAccent,
    Colors.blueAccent,
    Colors.orangeAccent,
    Colors.purpleAccent,
  ];

  @override
  void initState() {
    super.initState();
    _totalRounds = widget.settings.missionRounds;
    _initLevel();
  }

  void _initLevel() {
    _availableColors.shuffle();
    _targetColor = _availableColors.first;
    
    // Grid is 4x4 = 16 tiles
    _gridColors = List.generate(16, (index) => Colors.grey);
    _selectedTiles = List.generate(16, (index) => false);
    
    _targetCount = 4 + (_random.nextInt(3)); // 4 to 6 targets
    
    List<int> indices = List.generate(16, (i) => i);
    indices.shuffle();
    
    // Place targets
    for (int i = 0; i < _targetCount; i++) {
      _gridColors[indices[i]] = _targetColor;
    }
    
    // Place random distractors
    for (int i = _targetCount; i < 16; i++) {
      Color distractor = _availableColors[1 + _random.nextInt(_availableColors.length - 1)];
      _gridColors[indices[i]] = distractor;
    }
    
    setState(() {});
  }

  void _onTileTap(int index) {
    Haptics.vibrate(HapticsType.light);
    if (_gridColors[index] == _targetColor) {
      setState(() {
        _selectedTiles[index] = true;
      });
      _checkWin();
    } else {
      // Wrong tile, reset
      Haptics.vibrate(HapticsType.heavy);
      _initLevel();
    }
  }

  void _checkWin() {
    int found = 0;
    for (int i = 0; i < 16; i++) {
      if (_gridColors[i] == _targetColor && _selectedTiles[i]) found++;
    }
    if (found == _targetCount) {
      _currentRound++;
      if (_currentRound >= _totalRounds) {
        widget.onSuccess();
      } else {
        Haptics.vibrate(HapticsType.success);
        setState(() {
          _initLevel();
        });
      }
    }
  }

  String _getColorName(Color c) {
    if (c == Colors.redAccent) return "Red";
    if (c == Colors.greenAccent) return "Green";
    if (c == Colors.blueAccent) return "Blue";
    if (c == Colors.orangeAccent) return "Orange";
    if (c == Colors.purpleAccent) return "Purple";
    return "Target";
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Round ${_currentRound + 1} of $_totalRounds",
          style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "Find all ${_getColorName(_targetColor)} tiles",
          style: TextStyle(color: colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: _targetColor,
            shape: BoxShape.circle,
            border: Border.all(color: Colors.white, width: 2),
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 4,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
            ),
            itemCount: 16,
            itemBuilder: (context, index) {
              bool isSelected = _selectedTiles[index];
              return GestureDetector(
                onTap: isSelected ? null : () => _onTileTap(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  decoration: BoxDecoration(
                    color: isSelected ? _gridColors[index].withValues(alpha: 0.3) : _gridColors[index],
                    borderRadius: BorderRadius.circular(16),
                    border: isSelected ? Border.all(color: colorScheme.onSurface.withValues(alpha: 0.54), width: 2) : null,
                  ),
                  child: Center(
                    child: isSelected ? Icon(Icons.check, color: colorScheme.onSurface) : null,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
