import 'dart:math';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'mission_interface.dart';

class MemoryMission extends MissionWidget {
  final int difficulty;

  const MemoryMission({
    Key? key, 
    required VoidCallback onSuccess, 
    required VoidCallback onSkip,
    this.difficulty = 1000,
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
  
  List<int> _sequence = [];
  List<int> _userSequence = [];
  int _activeFlash = -1;
  bool _isPlayingSequence = false;
  
  @override
  void initState() {
    super.initState();
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
      int targetLength = widget.difficulty <= 400 ? 4 : widget.difficulty <= 1000 ? 6 : 8;
      
      if (_sequence.length >= targetLength) {
        Haptics.vibrate(HapticsType.success);
        widget.onSuccess();
      } else {
        _startNewSequence(); // Next level
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
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
          'Level ${_sequence.length} of ${widget.difficulty <= 400 ? 4 : widget.difficulty <= 1000 ? 6 : 8}',
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 16),
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
                    color: isFlashing ? _baseColors[index] : _baseColors[index].withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isFlashing ? colorScheme.onSurface : _baseColors[index].withOpacity(0.3),
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
          child: Text('Skip (-10 Elo)', style: TextStyle(color: colorScheme.error, fontSize: 16)),
        ),
      ],
    );
  }
}
