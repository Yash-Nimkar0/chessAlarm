import 'package:flutter/material.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class HardcoreWakeScreen extends StatefulWidget {
  final DateTime alarmTime;
  const HardcoreWakeScreen({Key? key, required this.alarmTime}) : super(key: key);

  @override
  State<HardcoreWakeScreen> createState() => _HardcoreWakeScreenState();
}

class _HardcoreWakeScreenState extends State<HardcoreWakeScreen> {
  late Timer _timer;
  String _currentTimeString = "";
  int _currentStreak = 0;

  @override
  void initState() {
    super.initState();
    WakelockPlus.enable();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _updateTime());
    _loadStreak();
  }
  
  void _loadStreak() async {
    if (mounted) {
      setState(() {
        _currentStreak = 0;
      });
    }
  }

  void _updateTime() {
    final now = DateTime.now();
    setState(() {
      _currentTimeString = DateFormat('h:mm a').format(now);
    });
  }

  @override
  void dispose() {
    _timer.cancel();
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              const Icon(Icons.shield_moon, color: Colors.blueAccent, size: 64),
              const SizedBox(height: 24),
              Text(
                _currentTimeString,
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontSize: 72,
                  fontWeight: FontWeight.w200,
                  letterSpacing: -2,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Hardcore Wake Mode',
                style: TextStyle(
                  color: Colors.blueAccent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Alarm armed for ${DateFormat('h:mm a').format(widget.alarmTime)}',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 64),
              
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.12)),
                ),
                child: Column(
                  children: [
                    Text('Tomorrow\'s Challenge', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 14)),
                    const SizedBox(height: 8),
                    Text('🌟 Daily Mission', style: TextStyle(color: Theme.of(context).colorScheme.onSurface, fontSize: 24, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orangeAccent, size: 20),
                        const SizedBox(width: 8),
                        Text('Current streak: $_currentStreak days', style: const TextStyle(color: Colors.orangeAccent, fontWeight: FontWeight.bold)),
                      ],
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text('Sleep well.', style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.38), fontSize: 18, fontStyle: FontStyle.italic)),
              const SizedBox(height: 24),
              
              Opacity(
                opacity: 0.3,
                child: TextButton.icon(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: Theme.of(context).colorScheme.onSurface),
                  label: Text('Exit Wake Mode', style: TextStyle(color: Theme.of(context).colorScheme.onSurface)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
