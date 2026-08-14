import 'package:flutter/material.dart';
import 'package:haptic_feedback/haptic_feedback.dart';
import 'dart:math';

import '../../models/mission_settings.dart';

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

class _MissingSymbolMissionState extends State<MissingSymbolMission> {
  final Random _random = Random();
  late int _num1;
  late int _num2;
  late int _result;
  late String _correctSymbol;
  
  int _currentRound = 0;
  late int _totalRounds;
  
  final List<String> _symbols = ['+', '-', '*', '/'];

  @override
  void initState() {
    super.initState();
    _totalRounds = widget.settings.missionRounds;
    _generateEquation();
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
      setState(() {
        _generateEquation(); // Regenerate on mistake to prevent brute force
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Round ${_currentRound + 1} of $_totalRounds",
          style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 12),
        const Text(
          "Find the missing symbol",
          style: TextStyle(color: Colors.white70, fontSize: 18),
        ),
        const SizedBox(height: 40),
        Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("$_num1", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withOpacity(0.5)),
                ),
                child: const Center(child: Text("?", style: TextStyle(color: Colors.blueAccent, fontSize: 36, fontWeight: FontWeight.bold))),
              ),
              const SizedBox(width: 16),
              Text("$_num2", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              const Text("=", style: TextStyle(color: Colors.white54, fontSize: 48, fontWeight: FontWeight.bold)),
              const SizedBox(width: 16),
              Text("$_result", style: const TextStyle(color: Colors.white, fontSize: 48, fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        const SizedBox(height: 60),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 40),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: _symbols.map((s) => _buildSymbolButton(s)).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildSymbolButton(String symbol) {
    return GestureDetector(
      onTap: () => _onSymbolTap(symbol),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: Colors.blueAccent.withOpacity(0.2),
          shape: BoxShape.circle,
          border: Border.all(color: Colors.blueAccent),
        ),
        child: Center(
          child: Text(
            symbol,
            style: const TextStyle(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
          ),
        ),
      ),
    );
  }
}
