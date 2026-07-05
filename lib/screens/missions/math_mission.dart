import 'dart:math';
import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'mission_interface.dart';
import '../../widgets/platform_theme.dart';

class MathMission extends MissionWidget {
  final int difficulty;

  const MathMission({
    Key? key, 
    required VoidCallback onSuccess, 
    required VoidCallback onSkip,
    this.difficulty = 1000,
  }) : super(key: key, onSuccess: onSuccess, onSkip: onSkip);

  @override
  State<MathMission> createState() => _MathMissionState();
}

class _MathMissionState extends State<MathMission> {
  late int num1;
  late int num2;
  late int num3;
  late int correctAnswer;
  late List<int> options;

  late String _equationDisplay;

  @override
  void initState() {
    super.initState();
    _generateEquation();
  }

  void _generateEquation() {
    final random = Random();
    
    if (widget.difficulty <= 400) {
      // Easy: Addition
      num1 = random.nextInt(40) + 10;
      num2 = random.nextInt(40) + 10;
      correctAnswer = num1 + num2;
      _equationDisplay = '$num1 + $num2';
    } else if (widget.difficulty <= 1000) {
      // Medium: Multiplication
      num1 = random.nextInt(10) + 2;
      num2 = random.nextInt(10) + 2;
      correctAnswer = num1 * num2;
      _equationDisplay = '$num1 × $num2';
    } else {
      // Hard: BEDMAS
      num1 = random.nextInt(20) + 10;
      num2 = random.nextInt(10) + 2;
      num3 = random.nextInt(50) + 10;
      correctAnswer = (num1 * num2) + num3;
      _equationDisplay = '($num1 × $num2) + $num3';
    }

    options = [correctAnswer];
    while (options.length < 4) {
      int fake = correctAnswer + (random.nextInt(40) - 20);
      if (!options.contains(fake) && fake > 0) {
        options.add(fake);
      }
    }
    options.shuffle();
  }

  void _checkAnswer(int answer) {
    if (answer == correctAnswer) {
      Haptics.vibrate(HapticsType.success);
      widget.onSuccess();
    } else {
      Haptics.vibrate(HapticsType.error);
      setState(() {
        _generateEquation();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'SOLVE TO DISMISS',
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w900,
            color: colorScheme.onSurface,
            letterSpacing: 2.0,
          ),
        ),
        const SizedBox(height: 40),
        PlatformCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 30),
            child: Text(
              _equationDisplay,
              style: TextStyle(
                fontSize: 40,
                fontWeight: FontWeight.bold,
                color: colorScheme.primary,
              ),
            ),
          ),
        ),
        const SizedBox(height: 60),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            childAspectRatio: 2.5,
            crossAxisSpacing: 16,
            mainAxisSpacing: 16,
          ),
          itemCount: 4,
          itemBuilder: (context, index) {
            final opt = options[index];
            return PlatformButton(
              onPressed: () => _checkAnswer(opt),
              backgroundColor: colorScheme.surfaceContainerHighest,
              child: Text(
                opt.toString(),
                style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
            );
          },
        ),
        const SizedBox(height: 40),
        TextButton(
          onPressed: widget.onSkip,
          child: Text('Skip (-10 Elo)', style: TextStyle(color: colorScheme.error, fontSize: 16)),
        ),
      ],
    );
  }
}
