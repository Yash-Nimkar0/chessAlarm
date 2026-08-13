import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

class TypingMission extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;
  final int difficulty;

  const TypingMission({
    Key? key,
    required this.onSuccess,
    required this.onSkip,
    required this.difficulty,
  }) : super(key: key);

  @override
  State<TypingMission> createState() => _TypingMissionState();
}

class _TypingMissionState extends State<TypingMission> {
  final TextEditingController _controller = TextEditingController();
  late String _targetPhrase;
  
  final List<String> _phrases = [
    "I will wake up and seize the day",
    "Discipline equals freedom",
    "The early bird catches the worm",
    "Rise and shine, the world awaits",
    "Success is the sum of small efforts repeated",
  ];

  @override
  void initState() {
    super.initState();
    _phrases.shuffle();
    _targetPhrase = _phrases.first;
    
    _controller.addListener(_checkCompletion);
  }

  void _checkCompletion() {
    if (_controller.text == _targetPhrase) {
      widget.onSuccess();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.keyboard, size: 64, color: Colors.blueAccent),
        const SizedBox(height: 24),
        Text(
          "Type exactly what you see:",
          style: TextStyle(color: Colors.white.withOpacity(0.7), fontSize: 18),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
          ),
          child: Text(
            _targetPhrase,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.2,
            ),
            textAlign: TextAlign.center,
          ),
        ),
        const SizedBox(height: 40),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white, fontSize: 20),
            decoration: InputDecoration(
              hintText: "Start typing...",
              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
            autocorrect: false,
            autofocus: true,
          ),
        ),
      ],
    );
  }
}
