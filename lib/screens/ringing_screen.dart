import 'package:flutter/material.dart';
import 'package:alarm/alarm.dart';
import 'package:haptic_feedback/haptic_feedback.dart';

import 'dart:io';
import '../models/mission_settings.dart';
import 'missions/math_mission.dart';
import 'missions/memory_mission.dart';
import 'missions/typing_mission.dart';
import 'missions/color_tiles_mission.dart';
import 'missions/missing_symbol_mission.dart';
import 'missions/shake_mission.dart';
import 'missions/qr_mission.dart';
import 'missions/steps_mission.dart';
import 'mission_complete_screen.dart';
import '../theme/design_tokens.dart';
import '../widgets/platform_theme.dart';
import '../services/analytics_service.dart';
import '../services/elo_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../services/sleep_service.dart';

class RingingScreen extends StatefulWidget {
  final AlarmSettings alarmSettings;
  const RingingScreen({Key? key, required this.alarmSettings}) : super(key: key);

  @override
  State<RingingScreen> createState() => _RingingScreenState();
}

class _RingingScreenState extends State<RingingScreen> with TickerProviderStateMixin {
  bool _isLoading = true;
  bool _isProcessing = false;
  bool _isSuccess = false;
  
  late AnimationController _pulseController;
  late Animation<Color?> _pulseAnimation;
  final bool _isFlashingRed = false;

  late AnimationController _sunriseController;
  late Animation<Color?> _skyAnimation;

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

    _sunriseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 30),
    );
    _skyAnimation = TweenSequence<Color?>([
      TweenSequenceItem(weight: 1.0, tween: ColorTween(begin: AppTokens.nightBg, end: AppTokens.dawnStart)),
      TweenSequenceItem(weight: 1.0, tween: ColorTween(begin: AppTokens.dawnStart, end: AppTokens.dawnEnd)),
    ]).animate(_sunriseController);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (MediaQuery.disableAnimationsOf(context)) {
        _sunriseController.value = 1.0;
      } else {
        _sunriseController.forward();
      }
    });

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
      if (_missionSettings.type == 'quickAlarm' || _missionSettings.type == 'alarm') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                    const SizedBox(height: 20),
                    Text('Wake up!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary, 
                        foregroundColor: Theme.of(context).colorScheme.onPrimary, 
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm))
                      ),
                      child: const Text("Done", style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
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
      await EloService.recordMorningSuccess(solveTimeSeconds: elapsed);
      if (_missionSettings.type == 'quickAlarm' || _missionSettings.type == 'alarm') {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (context) => Scaffold(
              backgroundColor: Theme.of(context).colorScheme.surface,
              body: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 80),
                    const SizedBox(height: 20),
                    Text('Wake up!', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.onSurface)),
                    const SizedBox(height: 40),
                    ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).colorScheme.primary,
                        foregroundColor: Theme.of(context).colorScheme.onPrimary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusSm))
                      ),
                      child: const Text("Done", style: TextStyle(fontSize: 18)),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      } else {
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
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _sunriseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppTokens.nightBg,
        body: Center(
          child: CircularProgressIndicator(color: AppTokens.signal),
        ),
      );
    }
    
    Widget content;
    int difficulty = _missionSettings.difficultyOverride ?? 400;
    
    if (_missionSettings.mission == 'math') {
      content = MathMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, settings: _missionSettings);
    } else if (_missionSettings.mission == 'memory') {
      content = MemoryMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, settings: _missionSettings);
    } else if (_missionSettings.mission == 'typing') {
      content = TypingMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, settings: _missionSettings);
    } else if (_missionSettings.mission == 'color_tiles') {
      content = ColorTilesMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, settings: _missionSettings);
    } else if (_missionSettings.mission == 'missing_symbol') {
      content = MissingSymbolMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, settings: _missionSettings);
    } else if (_missionSettings.mission == 'shake') {
      content = ShakeMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, settings: _missionSettings);
    } else if (_missionSettings.mission == 'qr') {
      content = QRMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, missionData: _missionSettings.missionData ?? {});
    } else if (_missionSettings.mission == 'steps') {
      content = StepsMission(onSuccess: _handleSuccess, onSkip: _skipPuzzle, missionData: _missionSettings.missionData ?? {});
    } else {
      content = Center(
        child: ElevatedButton(
          onPressed: _handleSuccess,
          style: ElevatedButton.styleFrom(
            backgroundColor: Theme.of(context).colorScheme.primary,
            padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 24),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppTokens.radiusLg)),
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
          animation: Listenable.merge([_pulseAnimation, _sunriseController]),
          builder: (context, child) {
            final skyColor = _skyAnimation.value ?? AppTokens.nightBg;
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
                            : skyColor,
                    AppTokens.nightBg,
                  ],
                )
              ),
              child: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Column(
                    children: [
                      if (_missionSettings.label != null && _missionSettings.label!.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, bottom: 8.0),
                          child: Text(
                            _missionSettings.label!,
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      Expanded(child: content),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
