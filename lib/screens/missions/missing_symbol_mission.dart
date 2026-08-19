import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'dart:math';

import '../../models/mission_settings.dart';
import '../../theme/design_tokens.dart';
import '../../widgets/animated_pressable.dart';

class MissingSymbolMission extends StatefulWidget {
  final VoidCallback onSuccess;
  final VoidCallback onSkip;
  final MissionSettings settings;

  const MissingSymbolMission({
    Key? key,
    required this.onSuccess,
    required this.onSkip,
    required this.settings,
  }) : super(key: key);

  @override
  State<MissingSymbolMission> createState() => _MissingSymbolMissionState();
}

class _MissingSymbolMissionState extends State<MissingSymbolMission> with SingleTickerProviderStateMixin {
  final Random _random = Random();
  late int _num1;
  late int _num2;
  late int _result;
  late String _correctSymbol;

  int _currentRound = 0;
  late int _totalRounds;

  final List<String> _symbols = ['+', '-', '*', '/'];

  late final AnimationController _shakeController;

  @override
  void initState() {
    super.initState();
    _totalRounds = widget.settings.missionRounds;
    _shakeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 400));
    _generateEquation();
  }

  @override
  void dispose() {
    _shakeController.dispose();
    super.dispose();
  }

  void _generateEquation() {
    _correctSymbol = _symbols[_random.nextInt(_symbols.length)];
    
    switch (_correctSymbol) {
      case '+':
        _num1 = 10 + _random.nextInt(50);
        _num2 = 10 + _random.nextInt(50);
        _result = _num1 + _num2;
        break;
      case '-':
        _num1 = 20 + _random.nextInt(50);
        _num2 = 5 + _random.nextInt(_num1 - 5);
        _result = _num1 - _num2;
        break;
      case '*':
        _num1 = 2 + _random.nextInt(10);
        _num2 = 2 + _random.nextInt(10);
        _result = _num1 * _num2;
        break;
      case '/':
        _num2 = 2 + _random.nextInt(10);
        _result = 2 + _random.nextInt(10);
        _num1 = _num2 * _result;
        break;
    }
    setState(() {});
  }

  void _onSymbolTap(String symbol) {
    if (symbol == _correctSymbol) {
      Haptics.vibrate(HapticsType.success);
      _currentRound++;
      if (_currentRound >= _totalRounds) {
        widget.onSuccess();
      } else {
        setState(() {
          _generateEquation();
        });
      }
    } else {
      Haptics.vibrate(HapticsType.error);
      _shakeController.forward(from: 0);
      setState(() {
        _generateEquation(); // Regenerate on mistake to prevent brute force
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
          "Round ${_currentRound + 1} of $_totalRounds",
          style: TextStyle(color: colorScheme.onSurfaceVariant.withValues(alpha: 0.5), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        Text(
          "Find the missing symbol",
          style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 18),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          decoration: BoxDecoration(
            color: colorScheme.onSurface.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(AppTokens.radiusLg),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text("$_num1", style: TextStyle(color: colorScheme.onSurface, fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: colorScheme.onSurface.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(AppTokens.radiusSm),
                  border: Border.all(color: AppTokens.signal, width: 2),
                ),
                child: Center(
                  child: Text("?", style: TextStyle(color: AppTokens.signal, fontSize: 32, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 16),
              Text("$_num2", style: TextStyle(color: colorScheme.onSurface, fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Text("=", style: TextStyle(color: colorScheme.onSurfaceVariant, fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Text("$_result", style: TextStyle(color: colorScheme.onSurface, fontSize: 48, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 60),
        AnimatedBuilder(
          animation: _shakeController,
          builder: (context, child) {
            final t = _shakeController.value;
            final shake = sin(t * pi * 6) * 10 * (1 - t);
            return Transform.translate(offset: Offset(shake, 0), child: child);
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: _symbols.map((s) => _buildSymbolButton(s, colorScheme)).toList(),
            ),
          ),
        ),
        const SizedBox(height: 40),
        TextButton(
          onPressed: widget.onSkip,
          child: Text('Skip (-10 Points)', style: TextStyle(color: colorScheme.error, fontSize: 16)),
        ),
      ],
    );
  }

  Widget _buildSymbolButton(String symbol, ColorScheme colorScheme) {
    return AnimatedPressable(
      onTap: () => _onSymbolTap(symbol),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppTokens.signal.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: AppTokens.signal),
        ),
        child: Center(
          child: Text(
            symbol,
            style: TextStyle(color: colorScheme.onSurface, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
