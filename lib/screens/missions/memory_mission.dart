import 'dart:math';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import '../../models/mission_settings.dart';
import 'mission_interface.dart';

class MemoryMission extends MissionWidget {
  final MissionSettings settings;

  const MemoryMission({
    Key? key, 
    required VoidCallback onSuccess, 
    required VoidCallback onSkip,
    required this.settings,
  }) : super(key: key, onSuccess: onSuccess, onSkip: onSkip);

  @override
  State<MemoryMission> createState() => _MemoryMissionState();
}

class _MemoryMissionState extends State<MemoryMission> {
  final List<Color> _baseColors = [
    Colors.redAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.orangeAccent,
  ];
  
  final List<int> _sequence = [];
  final List<int> _userSequence = [];
  int _activeFlash = -1;
  bool _isPlayingSequence = false;
  
  int _currentRound = 0;
  late int _totalRounds;
  late int _difficulty;

  @override
  void initState() {
    super.initState();
    _difficulty = widget.settings.difficultyOverride ?? 400;
    _totalRounds = widget.settings.missionRounds;
    _startNewSequence();
  }

  Future<void> _startNewSequence() async {
    setState(() {
      _userSequence.clear();
      _isPlayingSequence = true;
      _sequence.add(Random().nextInt(4));
    });
    
    await Future.delayed(const Duration(seconds: 1));
    
    for (int index in _sequence) {
      if (!mounted) return;
      setState(() => _activeFlash = index);
      Haptics.vibrate(HapticsType.selection);
      
      await Future.delayed(const Duration(milliseconds: 500));
      
      if (!mounted) return;
      setState(() => _activeFlash = -1);
      
      await Future.delayed(const Duration(milliseconds: 300));
    }
    
    if (mounted) {
      setState(() => _isPlayingSequence = false);
    }
  }

  void _onTileTapped(int index) {
    if (_isPlayingSequence) return;
    
    Haptics.vibrate(HapticsType.light);
    
    setState(() {
      _activeFlash = index;
    });
    
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) setState(() => _activeFlash = -1);
    });

    _userSequence.add(index);
    
    // Check if correct so far
    for (int i = 0; i < _userSequence.length; i++) {
      if (_userSequence[i] != _sequence[i]) {
        Haptics.vibrate(HapticsType.error);
        _startNewSequence(); // Restart on mistake
        return;
      }
    }
    
    // Check if sequence complete
    if (_userSequence.length == _sequence.length) {
      int targetLength = _difficulty <= 400 ? 4 : _difficulty <= 1000 ? 6 : 8;
      
      if (_sequence.length >= targetLength) {
        Haptics.vibrate(HapticsType.success);
        _currentRound++;
        if (_currentRound >= _totalRounds) {
          widget.onSuccess();
        } else {
          // Reset sequence for next round
          _sequence.clear();
          _startNewSequence();
        }
      } else {
        _startNewSequence(); // Next level
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _isPlayingSequence ? 'WATCH CAREFULLY' : 'REPEAT SEQUENCE',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: _isPlayingSequence ? colorScheme.primary : colorScheme.onSurface,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          "Round ${_currentRound + 1} of $_totalRounds",
          style: TextStyle(color: colorScheme.primary.withValues(alpha: 0.8), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 4),
        Text(
          'Sequence Length: ${_sequence.length} / ${_difficulty <= 400 ? 4 : _difficulty <= 1000 ? 6 : 8}',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 14),
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: 300,
          height: 300,
          child: GridView.builder(
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 20,
              mainAxisSpacing: 20,
            ),
            itemCount: 4,
            itemBuilder: (context, index) {
              final isFlashing = _activeFlash == index;
              return GestureDetector(
                onTap: () => _onTileTapped(index),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 150),
                  decoration: BoxDecoration(
                    color: isFlashing ? _baseColors[index] : _baseColors[index].withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFlashing ? colorScheme.onSurface : _baseColors[index].withValues(alpha: 0.3),
                      width: isFlashing ? 4 : 2,
                    ),
                  ),
                ),
              );
            },
            ),
          ),
          const SizedBox(height: 60),
          TextButton(
            onPressed: widget.onSkip,
            child: Text('Skip (-10 Points)', style: TextStyle(color: colorScheme.error, fontSize: 16)),
          ),
        ],
      ),
    );
  }
}
