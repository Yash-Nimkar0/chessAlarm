import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'dart:io';
import '../models/mission_settings.dart';
import 'missions/math_mission.dart';
import 'missions/memory_mission.dart';
import 'mission_complete_screen.dart';
import '../widgets/platform_theme.dart';
import '../services/analytics_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/sleep_service.dart';

class RingingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  const RingingScreen({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen> with SingleTickerProviderStateMixin {
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isSuccess = false;
  
  late AnimationController _pulseController;
  late Animation<Color?> _pulseAnimation;
  final bool _isFlashingRed = false;

  late MissionSettings _missionSettings;
  late DateTime _startTime;
  int _skipsUsed = 0;

  @override
  void initState() {
    super.initState();
    AnalyticsService.logEvent('alarm_triggered', {'alarm_id': widget.alarmSettings.id});
    _startTime = DateTime.now();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
    
    _pulseAnimation = ColorTween(
      begin: const Color(0xFF1A0000),
      end: const Color(0xFF4A0000),
    ).animate(_pulseController);

    _loadSkips();

    if (widget.alarmSettings.payload != null) {
      _missionSettings = MissionSettings.fromJsonString(widget.alarmSettings.payload!);
    } else {
      _missionSettings = MissionSettings(type: 'wakeRoutine');
    }

    _isLoading = false;
  }

  void _loadSkips() async {
    final prefs = await SharedPreferences.getInstance();
    final monthKey = 'skips_${DateTime.now().year}_${DateTime.now().month}';
    if (mounted) {
      setState(() {
        _skipsUsed = prefs.getInt(monthKey) ?? 0;
      });
    }
  }

  void _skipPuzzle() async {
    if (_isProcessing) return;
    
    final prefs = await SharedPreferences.getInstance();
    final monthKey = 'skips_${DateTime.now().year}_${DateTime.now().month}';
    final currentSkips = prefs.getInt(monthKey) ?? 0;
    
    if (currentSkips >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No Backup Unlocks remaining this month.')));
      return;
    }
    
    Haptics.vibrate(HapticsType.heavy);
    await prefs.setInt(monthKey, currentSkips + 1);
    AnalyticsService.logEvent('backup_unlock_used');
    
    if (mounted) {
      setState(() => _isProcessing = true);
    }
    
    await Alarm.stop(widget.alarmSettings.id);
    await _rescheduleIfRecurring();
    
    if (mounted) {
      int elapsed = DateTime.now().difference(_startTime).inSeconds;
      await SleepService.recordWakePerformance(elapsed, 0, true);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MissionCompleteScreen(
            elapsedSeconds: elapsed,
            eloChange: 0,
            isSkip: true,
          ),
        ),
      );
    }
  }

  Future<void> _rescheduleIfRecurring() async {
    final prefs = await SharedPreferences.getInstance();
    final String? daysJson = prefs.getString('alarm_days_${widget.alarmSettings.id}');
    if (daysJson != null) {
      try {
        final List<dynamic> decoded = jsonDecode(daysJson);
        final List<bool> days = decoded.map((e) => e as bool).toList();
        
        if (days.contains(true)) {
          // Find next occurrence
          DateTime candidate = widget.alarmSettings.dateTime.add(const Duration(days: 1));
          for (int i = 0; i < 7; i++) {
            int dayIndex = candidate.weekday - 1;
            if (days[dayIndex]) {
              final newSettings = widget.alarmSettings.copyWith(
                id: widget.alarmSettings.id,
                dateTime: candidate,
              );
              await Alarm.set(alarmSettings: newSettings);
              return;
            }
            candidate = candidate.add(const Duration(days: 1));
          }
        }
      } catch (e) {}
    }
  }

  void _handleSuccess() async {
    if (mounted) {
      setState(() {
        _isSuccess = true;
        _isProcessing = true;
      });
    }
    Haptics.vibrate(HapticsType.heavy);

    await Future.delayed(const Duration(seconds: 2));
    
    await Alarm.stop(widget.alarmSettings.id);
    await _rescheduleIfRecurring();
    
    if (mounted) {
      int elapsed = DateTime.now().difference(_startTime).inSeconds;
      AnalyticsService.logEvent('mission_completed', {
        'solve_time': elapsed,
      });
      await SleepService.recordWakePerformance(elapsed, 0, false);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => MissionCompleteScreen(
            elapsedSeconds: elapsed,
            eloChange: 0,
            isSkip: false,
          ),
        ),
      );
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: CircularProgressIndicator(color: Colors.redAccent),
        ),
      );
    }
    
    Widget content;
    int difficulty = _missionSettings.difficultyOverride ?? 400;
    
    if (_missionSettings.mission == 'math') {
      content = MathMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, difficulty: difficulty);
    } else if (_missionSettings.mission == 'memory') {
      content = MemoryMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, difficulty: difficulty);
    } else {
      content = Center(
        child: ElevatedButton(
          onPressed: _handleSuccess,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
          ),
          child: Text(
            'Stop Alarm',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onPrimary),
          ),
        ),
      );
    }

    return PopScope(
      canPop: _isSuccess,
      child: PlatformScaffold(
        body: AnimatedBuilder(
          animation: _pulseAnimation,
          builder: (context, child) {
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    _isSuccess 
                        ? Colors.green.withValues(alpha: 0.4) 
                        : _isFlashingRed 
                            ? Colors.red.withValues(alpha: 0.8) 
                            : (_pulseAnimation.value ?? Colors.black).withValues(alpha: Platform.isIOS ? 0.3 : 1.0),
                    Colors.black.withValues(alpha: Platform.isIOS ? 0.2 : 1.0),
                  ],
                )
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: content,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
