import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import '../../models/mission_settings.dart';
import '../../models/default_quotes.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/animated_pressable.dart';

class TypingMission extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;
  final MissionSettings settings;

  const TypingMission({
    Key? key,
    required this.onSuccess,
    required this.onSkip,
    required this.settings,
  }) : super(key: key);

  @override
  State<TypingMission> createState() => _TypingMissionState();
}

class _TypingMissionState extends State<TypingMission> {
  final TextEditingController _controller = TextEditingController();
  late String _targetPhrase;

  int _currentRound = 0;
  late int _totalRounds;
  late List<String> _phrases;

  // Whether what's typed so far still matches the start of the target
  // phrase — without this, a typo just sat there silently until the user
  // noticed the whole string never lit up green, easy to miss half asleep.
  bool _isWrongSoFar = false;

  @override
  void initState() {
    super.initState();
    _totalRounds = widget.settings.missionRounds;

    final data = widget.settings.missionData;
    if (data != null && data['enabled_quotes'] != null && (data['enabled_quotes'] as List).isNotEmpty) {
      _phrases = List<String>.from(data['enabled_quotes']);
    } else {
      _phrases = List<String>.from(DefaultQuotes.quotes);
    }

    _phrases.shuffle();
    _targetPhrase = _phrases.first;

    _controller.addListener(_checkCompletion);
  }

  void _checkCompletion() {
    final typed = _controller.text.trim().toLowerCase();
    final target = _targetPhrase.trim().toLowerCase();

    if (typed == target) {
      Haptics.vibrate(HapticsType.success);
      if (_currentRound + 1 >= _totalRounds) {
        // Last round: leave _currentRound as-is so any rebuild during the
        // success transition still shows "N of N", not "N+1 of N".
        widget.onSuccess();
      } else {
        setState(() {
          _currentRound++;
          _controller.clear();
          _phrases.shuffle();
          _targetPhrase = _phrases.first;
          _isWrongSoFar = false;
        });
      }
      return;
    }

    final wrongNow = !target.startsWith(typed);
    if (wrongNow != _isWrongSoFar) {
      if (wrongNow) Haptics.vibrate(HapticsType.light);
      setState(() => _isWrongSoFar = wrongNow);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Quote ${_currentRound + 1} of $_totalRounds",
          style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 16),
        ),
        const SizedBox(height: 12),
        const Icon(Icons.keyboard_outlined, size: 48, color: Colors.indigoAccent),
        const SizedBox(height: 16),
        Text(
          'Type the phrase below:',
          style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.7), fontSize: 18),
        ),
        const SizedBox(height: 24),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            border: Border.all(color: Colors.indigoAccent.withValues(alpha: 0.3)),
          ),
          child: Text(
            _targetPhrase,
            textAlign: TextAlign.center,
            style: TextStyle(
              color: colorScheme.onSurface,
              fontSize: 22,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.1,
            ),
          ),
        ),
        const SizedBox(height: 40),
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppTokens.radiusSm),
            boxShadow: _isWrongSoFar
                ? [BoxShadow(color: colorScheme.error.withValues(alpha: 0.3), blurRadius: 12, spreadRadius: 1)]
                : null,
          ),
          child: TextField(
            controller: _controller,
            autofocus: true,
            textAlign: TextAlign.center,
            style: TextStyle(color: _isWrongSoFar ? colorScheme.error : colorScheme.onSurface, fontSize: 20),
            decoration: InputDecoration(
              hintText: 'Start typing...',
              hintStyle: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3)),
              filled: true,
              fillColor: _isWrongSoFar ? colorScheme.error.withValues(alpha: 0.1) : colorScheme.surfaceContainerHighest,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                borderSide: BorderSide.none,
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                borderSide: BorderSide(color: _isWrongSoFar ? colorScheme.error : Colors.indigoAccent, width: 2),
              ),
            ),
          ),
        ),
        const SizedBox(height: 40),
        AnimatedPressable(
          onTap: widget.onSkip,
          child: Text('Skip (-10 Points)', style: TextStyle(color: colorScheme.error, fontSize: 16)),
        ),
      ],
    ),
    );
  }
}
